require "monitor"

module Patches
  module RubyLLM
    module MCP
      module Native
        module TransportPatch
          extend ActiveSupport::Concern

          def transport_protocol
            native_transport_protocol_mutex.synchronize { super }
          end

          private

          def native_transport_protocol_mutex
            @native_transport_protocol_mutex ||= Monitor.new
          end
        end
      end
    end
  end
end
