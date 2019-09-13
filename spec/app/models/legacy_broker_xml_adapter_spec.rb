require 'spec_helper'

describe LegacyBrokerXmlAdapter do
  let(:tmp_path) { Dir.mktmpdir}
  let(:tmp_zip_path) { tmp_path + ".zip"}
  let(:encoded_broker_data) {
    broker_digest =  File.open('spec/data/app/controllers/broker_ach_cv.xml').read
    Zip::File.open(tmp_zip_path, Zip::File::CREATE) do  |zipfile|
      zipfile.mkdir("broker_xmls")
      zipfile.get_output_stream("broker_xmls/1234.xml") {|os| os.write(broker_digest) }
    end
    raw_broker_data = File.read(tmp_zip_path)
    Base64.encode64(raw_broker_data)
  }
  subject { LegacyBrokerXmlAdapter.new(encoded_broker_data) }

  describe "should generate broker xml" do
    it "should have legacy broker attributes" do
      subject.create_output do |output|
        doc = Nokogiri::XML(output.read)
        expect(doc.xpath("//ns1:broker_payment_accounts//ns1:broker_payment_account/ns1:routing_number").text).to eq "1111111111"
        expect(doc.xpath("//ns1:npn").text).to eq "1212127"
        expect(doc.xpath("//ns1:state").text).to eq ExchangeInformation.hbx_id.upcase.gsub!(/\d+/,"")
      end
      FileUtils.rm_rf(tmp_path)
      FileUtils.rm_rf(tmp_zip_path)
    end
  end

end
