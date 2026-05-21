module Patches
  module Faraday
    module Logging
      module FormatterPatch
        private

        def apply_filters(output)
          super
        rescue Regexp::TimeoutError => e
          "[log filtering failed: #{e.class}: #{e.message}]"
        end
      end
    end
  end
end
