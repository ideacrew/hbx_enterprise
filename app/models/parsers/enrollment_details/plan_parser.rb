module Parsers
  module EnrollmentDetails
    class PlanParser

      attr_reader :enrollees
      attr_accessor :enrollment_group_id, :employer

      def initialize(node, elected_aptc, is_shop = false)
        @xml = node
        @market = ""
        @broker = {}
        @elected_aptc = elected_aptc
        @is_shop = is_shop
        @employer = nil
      end

      def market=(market_type)
        @market = market_type
      end

      def market
        @market
      end

      def broker=(broker)
        @broker = broker
      end

      def broker
        @broker
      end

      def has_broker?
        !@broker.empty?
      end

      def plan_name
        @xml.at_xpath("plan/plan-name").text
      end

      def hios_id
        @xml.at_xpath("plan/plan-id").text
      end

      def dental?
        Maybe.new(@xml.at_xpath("plan/product-line")).text.downcase.value == "dental"
      end

      def premium_total
        Maybe.new(@xml.at_xpath("plan/premium")).text.to_f.value || 0.00
      end

      def carrier_display_name
        Maybe.new(@xml.at_xpath("plan/plan-carrier/carrier-name")).text.value
      end

      def carrier_active
        true
      end

      def coverage_type
        "urn:openhbx:terms:v1:benefit_coverage##{Maybe.new(@xml.at_xpath("plan/product-line")).text.downcase.value}"
      end

      def metal_level
        "urn:openhbx:terms:v1:plan_metal_level##{Maybe.new(@xml.at_xpath("plan/plan-tier")).text.downcase.value}"
      end

      def ehb_percent
        (Maybe.new(@xml.at_xpath("plan/ehb-percent")).text.to_f.value || 0.00)
      end

      def employer_responsible_amount
        (Maybe.new(@xml.at_xpath("contribution-amount")).text.to_f.value || 0.00)
      end

      def person_premiums_with_person_ids
        results = {}
        @xml.xpath("plan/person-premiums/person-premium").each do |node|
          person_id = node.at_xpath("person-id").text
          value = node.at_xpath("premium").text
          results[person_id] = value
        end
        results
      end

      def person_premiums(idMapping)
      results = {}
      person_premiums_with_person_ids.each do |person_id, premium|
        results[idMapping[person_id]] = premium
      end
      results
      end

      def applied_aptc
        return 0.00 if dental?
        max_aptc = (ehb_percent * 0.01) * premium_total
        aptc = (max_aptc < @elected_aptc) ? max_aptc : @elected_aptc
        sprintf('%.2f', aptc).to_f
      end

      def total_responsible_amount
        if @is_shop
          res_amt = premium_total - employer_responsible_amount
          sprintf('%.2f', res_amt).to_f
        else
          res_amt = premium_total - applied_aptc
          sprintf('%.2f', res_amt).to_f
        end
      end

      def plan_year
        plan_id_year = Maybe.new(@xml.at_xpath("plan/plan-id-year")).text.value
        plan_id_year.split(//).last(4).join
      end

      def plan_id
        "urn:openhbx:terms:v1:hios_id##{hios_id}"
      end

      def assign_enrollees(enrollees, id_map)

        person_premiums_array = person_premiums(id_map)

        @enrollees = enrollees.select do |enrollee|
          person_premiums_array.keys.include? enrollee.hbx_id
        end

        @enrollees.each do |enrollee|
          enrollee.premium_amount[plan_id] = person_premiums_array[enrollee.hbx_id]
        end

        @enrollees
      end

      def carrier_id
        Maybe.new(@xml.at_xpath("plan/plan-carrier/carrier-id")).text.value
      end

      def self.build(xml_node, elected_aptc, is_shop = false)
        self.new(xml_node, elected_aptc, is_shop)
      end
    end
  end
end
