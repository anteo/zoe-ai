# frozen_string_literal: true

module AI
  module Speech
    DEFAULT_RESPONSE_FORMAT = "mp3"
    CACHE_KEY_PREFIX = "tts_audio"

    module_function

    def speak(input, model: nil, provider: nil, assume_model_exists: false, voice: nil, style: nil, context: nil, **options)
      config = context&.config || RubyLLM.config
      model ||= config.default_tts_model
      style = style.to_s.strip.downcase.presence
      model, provider_instance = RubyLLM::Models.resolve(
        model,
        provider:,
        assume_exists: assume_model_exists,
        config:
      )

      speech_options = render_options(provider_instance:, style:, **options)
      provider_instance.speak(input.to_s, model: model.id, voice:, **speech_options)
    end

    def cache_key(token)
      "#{CACHE_KEY_PREFIX}:#{token}"
    end

    def render_options(provider_instance:, style: nil, **options)
      rendered = options.compact
      rendered[:response_format] ||= DEFAULT_RESPONSE_FORMAT

      if style.present? && openrouter_provider?(provider_instance)
        rendered[:provider_options] = rendered.fetch(:provider_options, {}).merge(style:)
      end

      rendered
    end

    def openrouter_provider?(provider_instance)
      provider_instance.is_a?(RubyLLM::Providers::OpenRouter)
    end
  end
end
