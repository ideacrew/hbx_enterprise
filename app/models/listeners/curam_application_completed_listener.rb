require 'json'

module Listeners
  class CuramApplicationCompletedListener < Amqp::Client
    class EmptyCuramResponseError < StandardError; end
    
    def on_message(delivery_info, properties, payload)
      query_service = ::Proxies::CuramCaseQuery.new
      payload = extract_ic_id(payload)
      code, body = query_service.invoke(payload, 30)
      case code.to_s
      when "406"
        # Invalid server response - send an event
        service_failure_event(
          "service_response_invalid",
          "406",
          JSON.dump({
            :original_request => payload,
            :service_response => (body.document.nil? ? "" : body.document.canonicalize),
            :validation_errors => body.errors.full_messages
          })
        )
        raise EmptyCuramResponseError.new(payload)
      when "503"
        # We got a timeout - send an event
        service_failure_event("service_timeout", "503", payload)
        requeue(delivery_info)
      when "200"
        # Everything is cool - just respond
        send_response("200", normalize_ids(body))
        channel.ack(delivery_info.delivery_tag,true)
      else
        # Some weirdness here - send event
        service_failure_event(
          "unknown_error",
          code,
          JSON.dump({
            :original_request => payload,
            :service_response => body.to_s
          })
        )
        requeue(delivery_info)
      end
    end

    def requeue(delivery_info)
      channel.nack(delivery_info.delivery_tag,false, true)
    end

    def service_failure_event(failure_key, return_status, body)
      ex = channel.fanout(ExchangeInformation.event_publish_exchange, {:durable => true})
      event_key = "error.application.curam.integrated_case_query.#{failure_key}"
      event_properties = {
        :timestamp => Time.now.to_i,
        :routing_key => event_key,
        :headers => {
          :return_status => return_status.to_s
        }
      }
      ex.publish(body.to_s, event_properties)
    end

    def send_response(status, body)
      response_properties = {
        :timestamp => Time.now.to_i,
        :routing_key => "info.events.family.application_completed",
        :headers => {
          :return_status => status
        }
      }
      ex = channel.fanout(ExchangeInformation.event_publish_exchange, {:durable => true})
      ex.publish(body.to_s, response_properties)
    end

    INTEGRATION_NS="http://CRMIntegrationACAPi/terms/1.0"

    def extract_ic_id(body)
      xml = Nokogiri::XML(body)
      xml.at_xpath("//cns:IntegratedCase_ID", {:cns => INTEGRATION_NS}).content
    end

    ID_QUERY_NS = "http://openhbx.org/api/terms/1.0"

    def normalize_ids(doc)
      xml = Nokogiri::XML(doc)
      id_nodes = xml.xpath("//idn:family_member/idn:id", {:idn => ID_QUERY_NS})
      id_mapping = {}
      id_nodes.each do |n|
        primary_id = n.at_xpath("idn:id", {:idn => ID_QUERY_NS}).content
        id_mapping[primary_id] = n.xpath("idn:alias_ids/idn:alias_id/idn:id", {:idn => ID_QUERY_NS}).map do |alias_id_node|
          alias_id_node.content
        end
      end
      updated_doc = doc
      id_mapping.each_pair do |k,v|
        v.each do |alias_id_val|
          updated_doc = updated_doc.gsub(alias_id_val, k)
        end
      end
      updated_doc
    end

    def self.queue_name
      ec = ExchangeInformation
      "#{ec.hbx_id}.#{ec.environment}.q.hbx_enterprise.curam_application_completed"
    end

    def self.queue_options
      ec = ExchangeInformation
      {:durable => true}
    end

    def self.run
      conn = Bunny.new(ExchangeInformation.amqp_uri, :heartbeat => 15)
      conn.start
      ch = conn.create_channel
      ch.prefetch(1)
      q = ch.queue(queue_name, queue_options)

      self.new(ch, q).subscribe(:block => true, :manual_ack => true)
      conn.close
    end
  end
end
