# frozen_string_literal: true

module Patches
  module RubyLLM
    module Providers
      module OpenRouter
        module ModelsPatch
          extend ActiveSupport::Concern

          def models_url
            "models?output_modalities=all"
          end

          def parse_list_models_response(...)
            super.map { normalize_speech_modalities(it) }
          end

          private

          def normalize_speech_modalities(model)
            output = model.modalities.output.map do |modality|
              modality == "speech" ? "audio" : modality
            end
            input = model.modalities.input.map(&:to_s)

            return model if output == model.modalities.output && input == model.modalities.input

            ::RubyLLM::Model::Info.new(
              model.to_h.merge(
                modalities: {
                  input:,
                  output:
                }
              )
            )
          end
        end
      end
    end
  end
end
