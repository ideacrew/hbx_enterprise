module ManualEnrollments

  class EnrollmentCvGenerator

    CV_XMLNS = {
      "xmlns" => 'http://openhbx.org/api/terms/1.0',
      "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance"
    }

    def initialize(enrollment, policy_id_generator, person_id_generator)
      @enrollment = enrollment
      @policy_id_generator = policy_id_generator
      @person_id_generator = person_id_generator
    end

    def generate_enrollment_cv
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.enrollment(CV_XMLNS) do |xml|
          xml.type @enrollment.type
          xml.market @enrollment.market_type
          xml.policy do |xml|
            xml.id do |xml|
              xml.id @policy_id_generator.unique_identifier
            end
            serialize_broker(@enrollment, xml)
            serialize_enrollees(@enrollment, xml)
            serialize_enrollment(@enrollment, xml)
          end
        end
      end
      # write_to_file builder.to_xml(:indent => 2)
      builder.to_xml(:indent => 2)
    end

    def serialize_broker(enrollment, xml)
      xml.broker do |xml|
        if enrollment.individual_market?
          xml.id do |xml|
            xml.id enrollment.broker_npn    
          end
          xml.name enrollment.broker
        end
      end
    end

    def serialize_enrollment(enrollment, xml)
      xml.enrollment do |xml|
        serialize_plan(enrollment.plan, enrollment, xml)
      end
    end

    def serialize_plan(plan, enrollment, xml)
      xml.plan do |xml|
        xml.id do |xml|
          xml.id plan.hios_id
        end
        xml.coverage_type 'urn:openhbx:terms:v1:qhp_benefit_coverage#health'
        xml.plan_year '2015'
        xml.name plan.name
        xml.is_dental_only false
      end

      enrollment.individual_market? ? serialize_individual_market(enrollment, xml) : serialize_shop_market(enrollment, xml) 
      xml.premium_total_amount format_amt(plan.premium_total)
      xml.total_responsible_amount format_amt(plan.responsible_amount)
    end

    def serialize_individual_market(enrollment, xml)
      xml.individual_market do |xml|
        xml.is_carrier_to_bill true
        xml.applied_aptc_amount format_amt(enrollment.plan.employer_contribution)
      end
    end

    def serialize_shop_market(enrollment, xml)
      xml.shop_market do |xml|
        xml.employer_link do |xml|
          xml.id do |xml|
            xml.id enrollment.fein.gsub("-",'')
          end
          xml.name enrollment.employer_name.camelcase
        end
        xml.total_employer_responsible_amount format_amt(enrollment.plan.employer_contribution)
      end
    end

    def serialize_enrollees(enrollment, xml)
      xml.enrollees do |xml|
        enrollment.enrollees.each do |enrollee|
          serialize_enrollee(enrollee, xml)
        end
      end
    end

    def serialize_enrollee(enrollee, xml)
      xml.enrollee do |xml|
        serialize_member(enrollee, xml)
        xml.is_subscriber (enrollee.relationship.downcase == 'self')
        xml.benefit do |xml|
          xml.begin_date format_date(@enrollment.benefit_begin_date)
          xml.premium_amount format_amt(enrollee.premium)
        end
      end  
    end

    def serialize_member(enrollee, xml)
      xml.member do |xml|
        id = @person_id_generator.unique_identifier
        serialize_person_id(enrollee, xml, id)
        serialize_person(enrollee, xml, id)
        serialize_relationships(enrollee, xml)
        serialize_demographics(enrollee, xml)
      end      
    end

    def serialize_person(enrollee, xml, id)
      xml.person do |xml|
        serialize_person_id(enrollee, xml, id)
        serialize_names(enrollee, xml)
        serialize_address(enrollee, xml)
        serialize_email(enrollee, xml)
        serialize_phone(enrollee, xml)
      end
    end

    def serialize_relationships(enrollee, xml)
      xml.person_relationships do |xml|
        xml.person_relationship do |xml|
          xml.subject_individual do |xml|
            xml.id @person_id_generator.current
          end
          xml.relationship_uri 'urn:openhbx:terms:v1:individual_relationship#' + enrollee.relationship.downcase
          xml.object_individual do |xml|
            xml.id @subscriber_id
          end
        end
      end
    end

    def serialize_demographics(enrollee, xml)
      xml.person_demographics do |xml|
        xml.ssn format_ssn(enrollee.ssn) if !enrollee.ssn.blank?
        xml.sex 'urn:openhbx:terms:v1:gender#' + enrollee.gender.downcase if !enrollee.gender.blank?
        xml.birth_date format_date(enrollee.dob) if !enrollee.dob.blank?
      end
    end

    def serialize_person_id(enrollee, xml, id)
      xml.id do |xml|
        if enrollee.relationship.downcase == 'self'
          @subscriber_id = id
        end
        xml.id id
      end    
    end

    def serialize_names(enrollee, xml)
      xml.person_name do |xml|
        xml.person_surname enrollee.last_name
        xml.person_given_name enrollee.first_name
        xml.person_middle_name enrollee.middle_name if !enrollee.middle_name.blank?
      end
    end

    def serialize_address(enrollee, xml)
      if enrollee.address_1.blank?
        enrollee = @enrollment.subscriber
      end
      xml.addresses do |xml|
        xml.address do |xml|
          xml.type 'urn:openhbx:terms:v1:address_type#home'
          xml.address_line_1 enrollee.address_1
          xml.address_line_2 enrollee.address_2 if !enrollee.address_2.blank?
          xml.location_city_name enrollee.city
          xml.location_state_code enrollee.state
          xml.postal_code format_zip(enrollee.zip.to_s)
        end
      end
    end

    def serialize_email(enrollee, xml)
      xml.emails do |xml|
        if !enrollee.email.blank?
          xml.email do |xml|
            xml.type 'urn:openhbx:terms:v1:email_type#home'
            xml.email_address enrollee.email
          end
        end
      end
    end

    def serialize_phone(enrollee, xml)
      xml.phones do |xml|
        if !enrollee.phone.blank?
          xml.phone do |xml|
            xml.type 'urn:openhbx:terms:v1:phone_type#home'
            xml.full_phone_number enrollee.phone.gsub(/-/,'')
          end
        end
      end
    end

    private

    def format_ssn(ssn)
      return nil if ssn.blank?
      ssn.gsub!(/-/,'')
      (9 - ssn.size).times{ ssn = prepend_zero(ssn) }
      ssn
    end

    def format_zip(zip)
      zip.gsub!(/-/,'')
      (5 - zip.size).times{ zip = prepend_zero(zip) }
      zip
    end

    def format_date(date)
      date = Date.strptime(date,'%m/%d/%Y')
      date.strftime('%Y%m%d')
    end

    def prepend_zero(str)
      '0' + str
    end

    def format_amt(amt)
      amt.gsub(/(\$|\,)/, '').to_f.round(2)
    end

    def write_to_file(xml_string)
      File.open("#{Padrino.root}/enrollments/enrollment_#{@enrollment.subscriber.first_name + @enrollment.subscriber.last_name}.xml", 'w') do |file|
        file.write xml_string
      end
    end
  end
end