class ExchangeInformation

  class MissingKeyError < StandardError
    def initialize(key)
      super("Missing required key: #{key}") 
    end
  end

  include Singleton

  REQUIRED_KEYS = [
    'amqp_uri',
    'hbx_id', 'environment', 'receiver_id',
    'osb_host', 'osb_username', 'osb_password', 'osb_nonce', 'osb_created',
    'invalid_argument_queue', 'processing_failure_queue', 'event_exchange', 'request_exchange'
  ]

  attr_reader :config

  # TODO: I have a feeling we may be using this pattern
  #       A LOT.  Look into extracting it if we repeat.
  def initialize
    @config = YAML.load_file(File.join(HbxEnterprise::App.root,'..','config', 'exchange.yml'))
    ensure_configuration_values(@config)
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
end
