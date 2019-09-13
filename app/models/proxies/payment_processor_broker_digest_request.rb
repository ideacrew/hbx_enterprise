module Proxies
  class PaymentProcessorBrokerDigestRequest
    def request(data)
      current_time = Time.now.utc
      time_string = current_time.strftime("%Y%m%d%H%M%S") + current_time.usec.to_s[0..2]
      f_path = base_path + "BrokerData_" + time_string + ".xml"
      begin
        upload_file(data, f_path)
        ["200", nil]
      rescue Exception => e
        ["503", {
                  :error_message => e.message,
                  :error => e.inspect,
                  :stacktrace => e.backtrace.join("\n")
              }.to_json]
      end
    end

    def base_path
      ExchangeInformation.pp_sftp_broker_digest_path
    end

    def host
      ExchangeInformation.pp_sftp_host
    end

    def username
      ExchangeInformation.pp_sftp_username
    end

    def password
      ExchangeInformation.pp_sftp_password
    end

    def upload_file(f_data, f_path)
      Net::SSH.start(host, username, :password => password) do |ssh|
        sftp = ssh.sftp.connect!
        sftp.upload!(StringIO.new(f_data), f_path)
        begin
          sftp.close_channel
        rescue IOError
        end
      end
    end
  end
end
