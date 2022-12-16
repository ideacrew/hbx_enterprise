module Listeners
  class EmployerDigestPaymentProcessorListener < Amqp::RetryClient
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


    def publish_single_legacy_xml(delivery_info, headers, carrier_profile_name, digest_xml)
      r_code, r_payload = Proxies::PaymentProcessorEmployerDigestRequest.new.request(carrier_profile_name, digest_xml)
      case r_code.to_s
      when "200"
        # ALL GOOD
        log_response("info.application.hbx_enterprise.employer_digest_payment_processor_listener.digest_published",r_code, headers, digest_xml)
        log_response("info.application.hbx_enterprise.employer_digest_payment_processor_listener.service_response",
                     r_code,
                     headers,
                     {
                       digest_xml: digest_xml,
                       service_response: r_payload
                     }.to_json)
        channel.acknowledge(delivery_info.delivery_tag, false)
      when "503"
        log_response("error.application.hbx_enterprise.employer_digest_payment_processor_listener.timeout",r_code, headers, digest_xml)
        channel.reject(delivery_info.delivery_tag, false)
      else
        log_response("error.application.hbx_enterprise.employer_digest_payment_processor_listener.failure",r_code, headers, digest_xml)
        log_response("error.application.hbx_enterprise.employer_digest_payment_processor_listener.service_response",
                     r_code,
                     headers,
                     {
                       digest_xml: digest_xml,
                       service_response: r_payload
                     }.to_json)
        channel.acknowledge(delivery_info.delivery_tag, false)
      end
    end

    def on_message(delivery_info, properties, payload)
      digest_xml = fix_encoding(payload)
      headers = properties.headers || {}
      carrier_profile_name = headers["carrier_profile_name"]
      publish_single_legacy_xml(delivery_info, headers, carrier_profile_name, digest_xml)
    end

    def fix_encoding(xml)
      return xml if xml.nil? || xml.blank?
      if [Encoding::ASCII_8BIT].include?(xml.encoding)
        xml.force_encoding(Encoding::UTF_8)
      else
        xml
      end
    end

    def __check_encoding(string)
      [Encoding::ASCII_8BIT].include?(string.encoding)
    end

    def self.queue_name
      ec = ExchangeInformation
      "#{ec.hbx_id}.#{ec.environment}.q.hbx_enterprise.employer_digest_payment_processor_listener"
    end

    def self.create_queue(chan)
      ec = ExchangeInformation
      event_exchange = chan.topic(ec.event_exchange, {:durable => true})
      q = chan.queue(
        self.queue_name,
        {
          :durable => true,
          :arguments => {
            "x-dead-letter-exchange" => (self.queue_name + "-retry")
          }
        }
      )
      event_exchange = chan.topic(ec.event_exchange, {:durable => true})
      q.bind(event_exchange, {:routing_key => "info.events.trading_partner.legacy_employer_digest.published"})
      retry_q = chan.queue(
        (self.queue_name + "-retry"),
        {
          :durable => true,
          :arguments => {
            "x-dead-letter-exchange" => (self.queue_name + "-requeue"),
            "x-message-ttl" => 1000
          }
        }
      )
      retry_exchange = chan.fanout(
        (self.queue_name + "-retry"), :durable => true
      )
      requeue_exchange = chan.fanout(
        (self.queue_name + "-requeue"), :durable => true
      )
      retry_q.bind(retry_exchange, {:routing_key => ""})
      q.bind(requeue_exchange, {:routing_key => ""})
      q
    end

    def self.run
      conn = Bunny.new(ExchangeInformation.amqp_uri)
      conn.start
      ch = conn.create_channel
      q = create_queue(ch)
      ch.prefetch(1)
      self.new(ch, q).subscribe(:block => true, :manual_ack => true, :ack => true)
    end
  end
end
