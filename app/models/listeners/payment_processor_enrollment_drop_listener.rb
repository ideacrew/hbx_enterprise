module Listeners
  class PaymentProcessorEnrollmentDropListener < Amqp::Client
    def log_response(key, code, headers, body)
      broadcaster = Amqp::EventBroadcaster.new(connection)
      response_properties = {
        :timestamp => Time.now.to_i,
        :routing_key => key,
        :headers => headers.merge({
          :return_status => code
        })
      }
      broadcaster.broadcast(response_properties, body.to_s)
    end

    def send_uploaded_notification(headers, location, body)
      broadcaster = Amqp::EventBroadcaster.new(connection)
      response_properties = {
        :timestamp => Time.now.to_i,
        :routing_key => "info.events.payment_processor_transaction.transmitted",
        :headers => headers.merge({
          :return_status => "200",
          :upload_location => location
        })
      }
      broadcaster.broadcast(response_properties, body.to_s)
    end


    def publish_single_legacy_xml(delivery_info, headers, enrollment_xml)
      r_code, r_payload = Proxies::PaymentProcessorEnrollmentDropRequest.new.request(enrollment_xml)
      case r_code.to_s
      when "200"
        # ALL GOOD
        log_response("info.application.hbx_enterprise.payment_processor_enrollment_drop_listener.policy_uploaded",r_code, headers, enrollment_xml)
        log_response("info.application.hbx_enterprise.payment_processor_enrollment_drop_listener.service_response",
                     r_code,
                     headers,
                     {
                       policy_xml: enrollment_xml.encode('UTF-8', undef: :replace, replace: ''),
                       service_response: r_payload.encode('UTF-8', undef: :replace, replace: '')
                     }.to_json)
        send_uploaded_notification(headers, r_payload, enrollment_xml)
        channel.acknowledge(delivery_info.delivery_tag, false)
      else
        log_response("error.application.hbx_enterprise.payment_processor_enrollment_drop_listener.upload_failure",r_code, headers, enrollment_xml)
        log_response("error.application.hbx_enterprise.payment_processor_enrollment_drop_listener.service_response",
                     r_code,
                     headers,
                     {
                       policy_xml: enrollment_xml.encode('UTF-8', undef: :replace, replace: ''),
                       service_response: r_payload.encode('UTF-8', undef: :replace, replace: ''),
                     }.to_json)
        throw :terminate, :failed
      end
    end

    def on_message(delivery_info, properties, payload)
      headers = properties.headers || {}
      publish_single_legacy_xml(delivery_info, headers, payload)
    end

    def self.queue_name
      ec = ExchangeInformation
      "hbx.payment_processor_updates"
    end

    def self.run
      conn = Bunny.new(ExchangeInformation.amqp_uri)
      conn.start
      ch = conn.create_channel
      q = ch.queue(queue_name, :durable => true)
      ch.prefetch(1)
      self.new(ch, q).subscribe(:block => true, :manual_ack => true, :ack => true)
    end
  end
end
