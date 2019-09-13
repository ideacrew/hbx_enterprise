require 'spec_helper'
require 'nokogiri'

describe "app/views/brokers/broker.haml" do
  let(:broker_cv) { File.read("spec/data/app/controllers/broker_ach_cv.xml") }

  describe "render broker template for a given cv" do

    let!(:cv_hash) { Parsers::Xml::Cv::IndividualParser.parse(broker_cv).to_hash }
    let!(:rendered) { HbxEnterprise::App.prototype.helpers.partial("brokers/broker", :locals =>{ :individual=> cv_hash }, :engine => :haml )}
    let!(:doc) {Nokogiri::XML(rendered)}

    it "should include legacy broker xml attributes " do
      expect(doc.to_s).to include("<ns1:routing_number>1111111111</ns1:routing_number>")
      expect(doc.to_s).to include("<ns1:account_number>2222222222</ns1:account_number>")
      expect(doc.to_s).to include("<ns1:npn>1212127</ns1:npn>")
    end
  end

end