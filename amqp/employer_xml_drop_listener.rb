require "multi_forkr"

legacy_listeners = {
  Listeners::EmployerLegacyDigestListener => 1
}

employer_drop_listener = {
  Listeners::EmployerDigestDropListener => 1,
  Listeners::EmployerLegacyDigestTransformer => 1,
  Listeners::EmployerDigestPaymentProcessorListener => 1
}

legacy_broker_listeners = {
    Listeners::LegacyBrokerXmlPaymentProcessorListener => 1
}  #nfp

broker_drop_listener = {
    Listeners::LegacyBrokerXmlDropListener => 1,
    Listeners::BrokerLegacyDigestTransformer => 1
}  #carriers

employer_listeners = ExchangeInformation.provide_legacy_employer_group_files? ? employer_drop_listener.merge(legacy_listeners) : employer_drop_listener
broker_listeners = ExchangeInformation.provide_legacy_broker_files_to_payment_processor? ? broker_drop_listener.merge(legacy_broker_listeners) : broker_drop_listener
listeners = employer_listeners.merge(broker_listeners)
MultiForkr.new(listeners).run
