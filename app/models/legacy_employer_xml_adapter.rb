class LegacyEmployerXmlAdapter
  include Padrino::Rendering
  include Padrino::Helpers::RenderHelpers
  include Padrino::Helpers::OutputHelpers

  attr_reader :employer_digest

  XML_HEADER = <<-XMLCODE
<?xml version='1.0' encoding='utf-8'?>
<employers xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:ns1="http://dchealthlink.com/vocabulary/20131030/employer" xmlns="http://dchealthlink.com/vocabulary/20131030/employer">
XMLCODE

  XML_TRAILER = <<-XMLCODE
</employers>
XMLCODE

  XML_NS = {:cv => "http://openhbx.org/api/terms/1.0" }

  def initialize(digest)
    @employer_digest = Nokogiri::XML(digest)
    @carrier_output = Hash.new { |h, k| h[k] = initialize_new_output }
    @renderer = HbxEnterprise::App.prototype.helpers
    @employer_ids = []
  end

  def initialize_new_output
    xml_io = Tempfile.new("hbx_enterprise_legacy_employer_group_file")
    xml_io.write(XML_HEADER)
    xml_io
  end

  def parse_org(node, employer_digest)
    employer_id = node.at_xpath("cv:id/cv:id", XML_NS).content.strip
    return nil if @employer_ids.include?(employer_id)
    # Canonicalization is very expensive, better to hack it with adding the namespace
    namespaces = {}
    node.namespace_scopes.each do |ns_scope|
      node.add_namespace_definition(ns_scope.prefix, ns_scope.href)
    end
    # We have to write back out to XML because happymapper doesn't do
    # the right thing without full canonicalization, or at least a trick
    # that makes it seem like we did canonicalization
    org = Parsers::Xml::Cv::OrganizationParser.parse(node.canonicalize).to_hash
    @employer_ids.push(employer_id)
    org
  end

  def with_organization_strings
    employer_digest.xpath("//cv:employer_events/cv:employer_event/cv:body/cv:organization", XML_NS).reverse.each do |node|
      parsed_org = parse_org(node, employer_digest)
      yield parsed_org if parsed_org
    end
  end

  def create_output
    # V1 doesn't care about stuff that happened forever ago, strip it
    @employer_digest.xpath("//cv:plan_year", XML_NS).each do |node|
      plan_year_end_node = node.at_xpath("cv:plan_year_end", XML_NS)
      if plan_year_end_node
        plan_year_end_date = Date.strptime(plan_year_end_node.content.strip,"%Y%m%d") rescue nil
        if plan_year_end_date
          # Give it 3 extra days just for buffer/timezones, etc.
          if plan_year_end_date < (Date.today - 3.days)
            node.remove
          end
        else
          node.remove
        end
      else
        node.remove
      end
    end
    # Re-save document - Nokogiri#canonicalize can do some weird stuff if you pile
    # enough changes into a big enough file.  Writing then re-reading the
    # document reduces the chances of this.
    @employer_digest =  Nokogiri::XML(@employer_digest.to_xml)
    with_organization_strings do |parsed_org|
      render_v1_xml_for(parsed_org)
    end
    @carrier_output.each_pair do |k, v|
       v.write(XML_TRAILER)
       v.rewind
       yield [k, v]
       v.close
       v.unlink
    end
  end

  protected

  def render_v1_xml_for(parsed_org)
    @cv_hash = parsed_org
    @plan_year = latest_plan_year(@cv_hash[:employer_profile][:plan_years])

    if @plan_year
      @carriers = @plan_year[:elected_plans].map do |plan|
        plan[:carrier][:name]
      end.uniq
      @carriers.each do |carrier|
        @carrier = carrier
        group_xml = @renderer.partial "employers/legacy_v1", :locals => { :plan_year => @plan_year, :cv_hash => @cv_hash, :carrier => carrier}, :engine => :haml
        @carrier_output[@carrier].write(group_xml)
        group_xml = nil
      end
    end
  end

  def latest_plan_year(plan_years)
    return plan_years.first if plan_years.length == 1
    plan_years.sort_by do |plan_year|
      Date.strptime(plan_year[:plan_year_start], "%Y%m%d")
    end.last
  end
end
