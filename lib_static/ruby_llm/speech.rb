# frozen_string_literal: true

module RubyLLM
  class Speech
    attr_reader :data, :mime_type, :model

    def initialize(data:, model: nil, mime_type: nil)
      @data = data
      @model = model
      @mime_type = mime_type
    end

    def save(path)
      File.binwrite(File.expand_path(path), data)
      path
    end

    def self.speak(input, model: nil, provider: nil, assume_model_exists: false, voice: nil, context: nil, **options)
      config = context&.config || RubyLLM.config
      model ||= config.default_tts_model
      model, provider_instance = Models.resolve(
        model,
        provider:,
        assume_exists: assume_model_exists,
        config:
      )

      provider_instance.speak(input, model: model.id, voice:, **options)
    end
  end
end
