class ExchangeInformation

  class MissingKeyError < StandardError
    def initialize(key)
      super("Missing required key: #{key}") 
    end
  end

  include Singleton

  REQUIRED_KEYS = [
    'amqp_uri',
    'environment',
    'hbx_id',
    'event_exchange',
    'event_publish_exchange',
    'request_exchange',
    'invalid_argument_queue',
    'processing_failure_queue',
    'email_username',
    'email_password',
    'smtp_host',
    'smtp_port',
    'email_from_address',
    'email_domain',
    'nfp_integration_url',
    'nfp_integration_user_id',
    'nfp_integration_password',
    'case_query_url',
    'account_creation_url',
    'osb_host',
    'osb_username',
    'osb_password',
    'osb_nonce',
    'osb_created',
    'legacy_carrier_mappings',
    'pp_sftp_host',
    'pp_sftp_username',
    'pp_sftp_password',
    'pp_sftp_employer_digest_path',
    'pp_sftp_enrollment_path',
    'employer_xml_drop_url',
    'legacy_employer_xml_drop_url',
    'residency_url'
  ]

  attr_reader :config

  def initialize
    @config = YAML.load(ERB.new(File.read(File.join(HbxEnterprise::App.root,'..','config', 'exchange.yml'))).result)
    ensure_configuration_values(@config)
  end

  def self.provide_legacy_employer_group_files?
    self.instance.provide_legacy_employer_group_files?
  end

   def provide_legacy_employer_group_files?
    @drop_legacy_group_files ||= (config["drop_legacy_group_files"].to_s == "true")
  end

  def ensure_configuration_values(conf)
    REQUIRED_KEYS.each do |k|
      if @config[k].blank?
        raise MissingKeyError.new(k)
      end
    end
  end

  def self.define_key(key)
    define_method(key.to_sym) do
      config[key.to_s]
    end
    self.instance_eval(<<-RUBYCODE)
      def self.#{key.to_s}
        self.instance.#{key.to_s}
      end
    RUBYCODE
  end

  REQUIRED_KEYS.each do |k|
    define_key k
  end

  def self.queue_name_for(klass)
    base_key = "#{self.hbx_id}.#{self.environment}.q.hbx_enterprise."
    base_key + klass.name.to_s.split("::").last.underscore
  end

  def self.use_soap_security?
    self.instance.use_soap_security?
  end

  def use_soap_security?
    @use_soap_security ||= extract_soap_security_setting
  end

  def extract_soap_security_setting
    config_val = config["use_soap_security"]
    return true if config_val.nil?
    !(config_val.to_s.downcase == "false")
  end
end
