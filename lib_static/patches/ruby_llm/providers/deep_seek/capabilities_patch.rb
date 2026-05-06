# frozen_string_literal: true

module Patches
  module RubyLLM
    module Providers
      module DeepSeek
        module CapabilitiesPatch
          extend ActiveSupport::Concern

          class_methods do
            def context_window_for(_model_id)
              64_000
            end

            def max_tokens_for(_model_id)
              8_192
            end

            def critical_capabilities_for(model_id)
              capabilities = []
              capabilities << "function_calling" if supports_tool_choice?(model_id)
              capabilities
            end

            def pricing_for(_model_id)
              {
                text_tokens: {
                  standard: {
                    input_per_million: nil,
                    output_per_million: nil
                  }
                }
              }
            end
          end
        end
      end
    end
  end
end
