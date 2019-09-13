require 'zip'
require 'nokogiri'

class LegacyBrokerXmlAdapter
  include Padrino::Rendering
  include Padrino::Helpers::RenderHelpers
  include Padrino::Helpers::OutputHelpers

 attr_reader :broker_digest_path

  XML_HEADER = <<-XMLCODE
<?xml version='1.0' encoding='utf-8' ?>
<brokers xmlns:ns1='urn:dchbx:brokerv1' xmlns:xsd='http://www.w3.org/2001/XMLSchema' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='urn:dchbx:brokerv1' xsi:schemaLocation='urn:dchbx:broker broker_20130903.xsd'>
  XMLCODE

  XML_TRAILER = <<-XMLCODE
</brokers>
  XMLCODE

  XML_NS = {:cv => "http://openhbx.org/api/terms/1.0" }

  def initialize(encoded_broker_data)
    @broker_xml_output = initialize_new_output
    @renderer = HbxEnterprise::App.prototype.helpers
    @encoded_broker_data = encoded_broker_data
    @broker_digest_path = get_broker_digest_path
  end

  def initialize_new_output
    xml_io = Tempfile.new("hbx_enterprise_legacy_broker_file")
    xml_io.write(XML_HEADER)
    xml_io
  end

  def get_broker_digest_path
    @decoded_broker_file = Tempfile.new("decoded_broker_digest_file.zip")
    File.open(@decoded_broker_file, 'wb') {|f| f.write(Base64.decode64(@encoded_broker_data))}
    broker_digest_path =  Dir.mktmpdir("broker_digest")
    Zip::File.open(@decoded_broker_file) do |zip_file|
      zip_file.each do |f|
        fpath = File.join(broker_digest_path, f.name)
        zip_file.extract(f, fpath) unless File.exist?(fpath)
      end
    end
    broker_digest_path
  end

  def parse_broker(broker_digest)
    Parsers::Xml::Cv::IndividualParser.parse(broker_digest).to_hash
  end

  def with_broker_strings(broker_digest_file)
    broker_digest = File.read(broker_digest_file)
    parsed_broker = parse_broker(broker_digest)
    yield parsed_broker if parsed_broker
  end

  def create_output
    Dir.glob("#{broker_digest_path}/broker_xmls/**/*").each do |broker_digest_file|
      with_broker_strings(broker_digest_file) do |parsed_broker|
        render_broker_xml_for(parsed_broker)
      end
    end
    @broker_xml_output.write(XML_TRAILER)
    @broker_xml_output.rewind
    yield @broker_xml_output if block_given?

    @broker_xml_output.close
    @broker_xml_output.unlink

    @decoded_broker_file.close
    @decoded_broker_file.unlink

    FileUtils.rm_rf(broker_digest_path)
  end

  protected

  def render_broker_xml_for(parsed_broker)
    @cv_hash = parsed_broker
    broker_xml = @renderer.partial "brokers/broker", :locals =>{ :individual=> @cv_hash }, :engine => :haml
    @broker_xml_output.write(broker_xml)
    broker_xml = nil
  end
end