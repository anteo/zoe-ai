require "monitor"

module Patches
  module RubyLLM
    module MCP
      module Native
        module ClientPatch
          extend ActiveSupport::Concern

          def ping
            native_client_lifecycle_mutex.synchronize { super }
          end

          def restart!
            native_client_lifecycle_mutex.synchronize { super }
          end

          def start
            native_client_lifecycle_mutex.synchronize { super }
          end

          def stop
            native_client_lifecycle_mutex.synchronize { super }
          end

          def transport
            native_client_transport_mutex.synchronize { super }
          end

        private

        def native_client_lifecycle_mutex
          @native_client_lifecycle_mutex ||= Monitor.new
        end

        def native_client_transport_mutex
          @native_client_transport_mutex ||= Monitor.new
        end
      end
    end
  end
end
end
