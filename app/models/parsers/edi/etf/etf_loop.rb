module Parsers
  module Edi
    module Etf
      class EtfLoop
        def initialize(etf_loop)
          @loop = etf_loop
        end

        def subscriber_loop
          @loop["L2000s"].detect do |l2000|
            l2000["INS"][2].strip == "18"
          end
        end

        def carrier_fein
          @loop["L1000B"]["N1"][4]
        end

        def employer_loop
          @loop["L1000A"]["N1"]
        end

        def is_shop?
          !(@loop["L1000A"]["N1"][2] == "DC0")
        end

        def people
          @loop['L2000s'].map { |p| PersonLoop.new(p) }
        end
      end
    end
  end
end