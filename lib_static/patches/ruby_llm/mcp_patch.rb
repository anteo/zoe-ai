require "monitor"

module Patches
  module RubyLLM
    module MCPPatch
      extend ActiveSupport::Concern

      class_methods do
        def add_client(...)
          mcp_clients_mutex.synchronize { super }
        end

        def clients(...)
          mcp_clients_mutex.synchronize { super }
        end

        def close_connection(...)
          mcp_clients_mutex.synchronize { super }
        end

        def remove_client(...)
          mcp_clients_mutex.synchronize { super }
        end

        def tools(...)
          mcp_clients_mutex.synchronize { super }
        end

        private

        def mcp_clients_mutex
          @mcp_clients_mutex ||= Monitor.new
        end
      end
    end
  end
end
