module Patches
  module RubyLLM
    module ModelsPatch
      FAKE_DEV_MODEL_ID = "fake-dev"
      FAKE_DEV_PROVIDER = "fake"

      def read_from_json(file = ::RubyLLM.config.model_registry_file)
        models = super
        return models unless Rails.env.development?

        models + development_models(models)
      end

      def load_existing_models
        models = super
        return models unless Rails.env.development?

        models + development_models(models)
      end

      def save_to_json(file = ::RubyLLM.config.model_registry_file)
        filtered_models = all.reject { |model| fake_dev_model?(model) }
        File.write(file, JSON.pretty_generate(filtered_models.map(&:to_h)))
      end

      private

      def development_models(existing_models)
        return [] unless ::RubyLLM::Provider.resolve(:fake)
        return [] if existing_models.any? { |model| fake_dev_model?(model) }

        ::AI::Providers::Fake.new(::RubyLLM.config).list_models
      end

      def fake_dev_model?(model)
        model.id == FAKE_DEV_MODEL_ID && model.provider == FAKE_DEV_PROVIDER
      end
    end
  end
end
