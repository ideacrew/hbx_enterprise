require "multi_forkr"

legacy_listeners = {
  Listeners::EmployerLegacyDigestListener => 1
}

employer_drop_listener = {
  Listeners::EmployerDigestDropListener => 1,
  Listeners::EmployerLegacyDigestTransformer => 1
}

employer_listeners = ExchangeInformation.provide_legacy_employer_group_files? ? employer_drop_listener.merge(legacy_listeners) : employer_drop_listener

MultiForkr.new(employer_listeners).run
