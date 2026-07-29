# frozen_string_literal: true

module Patches
  module RubyLLM
    module Providers
      module OllamaPatch
        CLOUD_ONLY_MODEL_TAG = "cloud"

        def parse_list_models_response(response, slug, capabilities)
          models = super
          models.reject { |model| cloud_only_model?(model) }
        end

        private

        def cloud_only_model?(model)
          model.id.to_s.split(":").last == CLOUD_ONLY_MODEL_TAG
        end
      end
    end
  end
end
