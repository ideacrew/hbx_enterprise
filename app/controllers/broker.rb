require 'nokogiri'

class HbxEnterprise::App

  post '/brokers/legacy_xml' do

     # file_path = "/Users/saidineshmekala/xml/Nov-18/ME/broker-cv/broker.xml" # dir_path where broker xml that need to be generated for NFP.
     #
     # file_path = "/Users/saidineshmekala/xml/Nov-18/broker-cv/broker.xml" # dir_path where broker xml that need to be generated for NFP.
    # # #
    file_path = "/Users/saidineshmekala/MA/Nov-18/broker-cv/nfp_broker.xml"   # MA
    carrier_br_file_path = "/Users/saidineshmekala/MA/Nov-18/broker-cv/carrier_broker.xml" # dir_path where broker xml that need to be generated for carrier's.

    @cv_hash = Parsers::Xml::Cv::IndividualParser.parse(request.body.read).to_hash
    # @cv_hash[:broker_roles].each do |broker_role|
    #   puts broker_role[:npn].strip
    # end
    broker_xml = render "brokers/legacy_broker", :locals =>{ :individual=> @cv_hash }
    File.open(file_path, 'a') { |file| file.write(broker_xml); }

    doc = Nokogiri::XML(broker_xml)
    doc.xpath("//cv:broker_payment_accounts", {:cv => 'urn:dchbx:brokerv1'}).each do |node|
      node.remove
    end

    File.open(carrier_br_file_path, 'a') { |file| file.write(doc.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION, :indent => 2)); }  # MA

    return
  end
end
