module Patches
  module RubyLLM
    module Model
      module InfoPatch
        def initialize(data)
          normalized = data.is_a?(Hash) ? data.dup : data

          if normalized.is_a?(Hash) && normalized[:created_at].is_a?(String) && normalized[:created_at].match?(/\A\d{4}-\d{2} 00:00:00 UTC\z/)
            normalized[:created_at] = "#{normalized[:created_at][0, 7]}-01 00:00:00 UTC"
          end

          super(normalized)
        end
      end
    end
  end
end
