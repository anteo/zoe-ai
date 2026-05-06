module Patches
  module RubyLLM
    module Providers
      module DeepSeek
        module CapabilitiesPatch
          extend ActiveSupport::Concern

          MODEL_DEFAULTS = {
            context_window: 1_000_000,
            max_output_tokens: 384_000,
            pricing: {
              input_per_million: nil,
              output_per_million: nil,
              cached_input_per_million: nil
            }
          }.freeze

          MODEL_CAPABILITIES = {
            "deepseek-v4-flash" => {
              pricing: {
                input_per_million: 0.14,
                output_per_million: 0.28,
                cached_input_per_million: 0.0028
              }
            },
            "deepseek-v4-pro" => {
              pricing: {
                input_per_million: 0.435,
                output_per_million: 0.87,
                cached_input_per_million: 0.003625
              }
            },
            "deepseek-chat" => {
              pricing: {
                input_per_million: 0.14,
                output_per_million: 0.28,
                cached_input_per_million: 0.0028
              }
            },
            "deepseek-reasoner" => {
              pricing: {
                input_per_million: 0.14,
                output_per_million: 0.28,
                cached_input_per_million: 0.0028
              }
            }
          }.freeze

          class_methods do
            def supports_tool_choice?(_model_id)
              true
            end

            def supports_tool_parallel_control?(_model_id)
              false
            end

            def context_window_for(model_id)
              model_capabilities_for(model_id)[:context_window]
            end

            def max_tokens_for(model_id)
              model_capabilities_for(model_id)[:max_output_tokens]
            end

            def critical_capabilities_for(model_id)
              capabilities = %w[function_calling structured_output]
              capabilities << "reasoning" if reasoning_model?(model_id)
              capabilities
            end

            def pricing_for(model_id)
              pricing = model_capabilities_for(model_id)[:pricing]

              {
                text_tokens: {
                  standard: {
                    input_per_million: pricing[:input_per_million],
                    output_per_million: pricing[:output_per_million],
                    cached_input_per_million: pricing[:cached_input_per_million]
                  }
                }
              }
            end

            def model_capabilities_for(model_id)
              MODEL_DEFAULTS.deep_merge(
                MODEL_CAPABILITIES.fetch(model_id.to_s.downcase, {})
              )
            end

            def reasoning_model?(model_id)
              normalized = model_id.to_s.downcase
              normalized.include?("reasoner") || normalized.start_with?("deepseek-v4-")
            end
          end
        end
      end
    end
  end
end
