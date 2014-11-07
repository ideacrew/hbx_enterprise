require 'spec_helper'

shared_examples "a plan parser" do


    it "should have the right name" do
      expect(subject.plan_name).to eql(plan_name)
    end
    it "should have the right hios_id" do
      expect(subject.hios_id).to eql(hios_id)
    end

    it "should have the right premium total" do
      expect(subject.premium_total).to eql(premium_total)
    end

    it "should have the right person premiums" do
      #allow(IdMapping).to receive(:from_person_id).and_return({'247857'=>'14.19', '248017'=>'16.64'})

      allow(idMapping).to receive(:from_person_id).with('247857').and_return('ret23eretret34324324')
      allow(idMapping).to receive(:from_person_id).with('248017').and_return('fsf43egeretret324324') 
      expect(subject.person_premiums(idMapping)).to eql(person_premiums)
    end

    it "should have the right ehb_percent" do
      expect(subject.ehb_percent).to eql(ehb_percent)
    end   
end

describe Parsers::EnrollmentDetails::PlanParser do
    let(:plan) {
      f = File.open(File.join(HbxEnterprise::App.root, "..", "spec", "data", "parsers", "enrollment_details", "#{file_name}_plan.xml"))
      Nokogiri::XML(f).root
    }

    let(:idMapping) {
      double
    }

    subject {
      Parsers::EnrollmentDetails::PlanParser.new(plan)
    }

  describe "given a dental plan" do
    let(:file_name) { "dental" }
    let(:plan_name) { "Select Plan" }
    let(:hios_id) { "92479DC0010002" }
    let(:premium_total) { "30.83" }
    #let(:person_premiums) {
    #  {"247857"=>"14.19", "248017"=>"16.64"}
    #}
    let(:person_premiums) {
      {"ret23eretret34324324"=>"14.19", "fsf43egeretret324324"=>"16.64"}
    }
    let(:ehb_percent) {"71.5"} 

    it_should_behave_like "a plan parser"

    it "should be a dental plan" do
      expect(subject).to be_dental
    end
  end

  describe "given a health plan" do
    let(:file_name) { "health" }
    let(:plan_name) { "BlueChoice HSA Bronze $6,000" }
    let(:hios_id) { "86052DC0410002-01" }
    let(:premium_total) { "262.60" }
    #let(:person_premiums) {
    #{
    #    "247857" => "129.68",
    #    "248017" => "132.92"
    #  }
    #}

    let(:person_premiums) {
      {"ret23eretret34324324"=>"129.68", "fsf43egeretret324324"=>"132.92"}
    }

    let(:ehb_percent) {"99.42"} 

    it_should_behave_like "a plan parser"

    it "should not be a dental plan" do
      expect(subject).not_to be_dental
    end
  end
end
