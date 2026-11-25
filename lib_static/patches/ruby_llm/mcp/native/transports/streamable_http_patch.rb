module Patches
  module RubyLLM
    module MCP
      module Native
        module Transports
          module StreamableHTTPPatch
            private

            def build_common_headers
              super.merge("Origin" => @url.origin)
            end
          end
        end
      end
    end
  end
end
