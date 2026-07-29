module Patches
  module RubyLLM
    module ModelsPatch
      extend ActiveSupport::Concern

      FAKE_DEV_MODEL_ID = "fake-dev"
      FAKE_DEV_PROVIDER = "fake"

      OLLAMA_CLOUD_MODELS_DEV_KEY = "ollama-cloud"
      OLLAMA_CLOUD_PROVIDER = "ollama_cloud"
      OLLAMA_LOCAL_PROVIDER = "ollama"
      CLOUD_ONLY_MODEL_TAG = "cloud"

      class_methods do
        def load_models(file = ::RubyLLM.config.model_registry_file)
          models = super
          reject_cloud_tagged_from_local_ollama(models)
        end

          def read_from_json(file = ::RubyLLM.config.model_registry_file)
          models = super
          models = map_models_dev_ollama_cloud(models)
          models = reject_cloud_tagged_from_local_ollama(models)
          return models unless Rails.env.development?

          models + development_models(models)
        end

        def load_existing_models
          models = super
          models = map_models_dev_ollama_cloud(models)
          models = reject_cloud_tagged_from_local_ollama(models)
          return models unless Rails.env.development?

          models + development_models(models)
        end

        def fake_dev_model?(model)
          model.id == FAKE_DEV_MODEL_ID && model.provider == FAKE_DEV_PROVIDER
        end

        def map_models_dev_ollama_cloud(models)
          models.map do |model|
            next model unless model.provider == OLLAMA_CLOUD_MODELS_DEV_KEY

            ::RubyLLM::Model::Info.new(model.to_h.merge(provider: OLLAMA_CLOUD_PROVIDER))
          end
        end

        def reject_cloud_tagged_from_local_ollama(models)
          models.reject do |model|
            model.provider == OLLAMA_LOCAL_PROVIDER && model.id.to_s.split(":").last == CLOUD_ONLY_MODEL_TAG
          end
        end

        private

        def development_models(existing_models)
          return [] unless ::RubyLLM::Provider.resolve(:fake)
          return [] if existing_models.any? { |model| fake_dev_model?(model) }

          ::AI::Providers::Fake.new(::RubyLLM.config).list_models
        end
      end

      def save_to_json(file = ::RubyLLM.config.model_registry_file)
        filtered_models = all.reject { |model| fake_dev_model?(model) }
        File.write(file, JSON.pretty_generate(filtered_models.map(&:to_h)))
      end

      delegate :fake_dev_model?, to: :class
    end
  end
end
