require "spec_helper"

shared_examples "a configuration lookup" do |key|
  it "with a key of #{key}" do
    expect(ExchangeInformation.send(key.to_sym)).not_to be_blank
  end
end

describe ExchangeInformation do
  it_behaves_like "a configuration lookup", "hbx_id"
  it_behaves_like "a configuration lookup", "environment"
  it_behaves_like "a configuration lookup", "receiver_id"
  it_behaves_like "a configuration lookup", 'osb_host'
  it_behaves_like "a configuration lookup", 'osb_username'
  it_behaves_like "a configuration lookup", 'osb_password'
  it_behaves_like "a configuration lookup", 'osb_nonce'
  it_behaves_like "a configuration lookup", 'osb_created'
  it_behaves_like "a configuration lookup", 'invalid_argument_queue'
  it_behaves_like "a configuration lookup", 'processing_failure_queue'
  it_behaves_like "a configuration lookup", 'event_exchange'
  it_behaves_like "a configuration lookup", 'request_exchange'
  it_behaves_like "a configuration lookup", 'broker_xml_drop_url'
  it_behaves_like "a configuration lookup", 'b2b_integration_api_key'
end
