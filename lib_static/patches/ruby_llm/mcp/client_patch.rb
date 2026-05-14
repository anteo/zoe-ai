require "monitor"

module Patches
  module RubyLLM
    module MCP
      module ClientPatch
        extend ActiveSupport::Concern

        def prompts(...)
          mcp_client_lifecycle_mutex.synchronize { super }
        end

        def resource_templates(...)
          mcp_client_lifecycle_mutex.synchronize { super }
        end

        def resources(...)
          mcp_client_lifecycle_mutex.synchronize { super }
        end

        def restart!
          mcp_client_lifecycle_mutex.synchronize { super }
        end

        def start
          mcp_client_lifecycle_mutex.synchronize { super }
        end

        def stop
          mcp_client_lifecycle_mutex.synchronize { super }
        end

        def tools(...)
          mcp_client_lifecycle_mutex.synchronize { super }
        end

        private

        def mcp_client_lifecycle_mutex
          @mcp_client_lifecycle_mutex ||= Monitor.new
        end
      end
    end
  end
end
