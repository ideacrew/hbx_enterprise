require 'pry'
class HbxEnterprise::App
  post '/employers/legacy_xml' do

    @cv_hash = Parsers::Xml::Cv::OrganizationParser.parse(request.body.read).to_hash

    if @cv_hash[:employer_profile][:plan_years].blank?
      puts "no active plan year fein= #{@cv_hash[:fein]}"
      return
    else
    # @plan_year = plan_year_for_year(@cv_hash[:employer_profile][:plan_years], '2017', '10', '1')
      @plan_year = latest_plan_year(@cv_hash[:employer_profile][:plan_years])
      puts "********* hbx_id=#{@cv_hash[:id]}****fein=#{@cv_hash[:fein]}**********plan_year=#{hiphen_saperated_date(@plan_year[:plan_year_start])}"
    end


    # if plan_year_for_year(@cv_hash[:employer_profile][:plan_years], '2014', '01', '04').present?
    #   @plan_year = plan_year_for_year(@cv_hash[:employer_profile][:plan_years], '2014', '01', '04')
    # elsif plan_year_for_year(@cv_hash[:employer_profile][:plan_years], '2015', '01', '04').present?
    #   @plan_year = plan_year_for_year(@cv_hash[:emplyer_profile][:plan_years], '2015', '01', '04')
    # elsif plan_year_for_year(@cv_hash[:employer_profile][:plan_years], '2016', '01', '04').present?
    #   @plan_year = plan_year_for_year(@cv_hash[:employer_profile][:plan_years], '2016', '01', '04')
    # else
    #   @plan_year = latest_plan_year(@cv_hash[:employer_profile][:plan_years])
    # end


    @carriers = @plan_year[:elected_plans].map do |plan| plan[:carrier][:name] end.uniq


    # dir_path = "/Users/saidineshmekala/IDEACREW/hbx_enterprise/test4/"
    dir_path = "/Users/saidineshmekala/xml/test/"


    @carriers.each do |carrier|
      @carrier = carrier
      group_xml = render "employers/legacy_employer"
      File.open(dir_path + @carrier + ".xml", 'a') { |file| file.write(group_xml) }
    end
  end
end