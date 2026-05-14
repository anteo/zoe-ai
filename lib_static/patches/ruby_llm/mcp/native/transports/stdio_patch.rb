require "monitor"

module Patches
  module RubyLLM
    module MCP
      module Native
        module Transports
          module StdioPatch
            extend ActiveSupport::Concern

            private

            def send_request(...)
              stdio_lifecycle_mutex.synchronize { super }
            end

            public

            def close
              stdio_lifecycle_mutex.synchronize { super }
            end

            def start
              stdio_lifecycle_mutex.synchronize { super }
            end

            private

            def stdio_lifecycle_mutex
              @stdio_lifecycle_mutex ||= Monitor.new
            end
          end
        end
      end
    end
  end
end
