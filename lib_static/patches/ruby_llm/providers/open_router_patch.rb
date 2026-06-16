# frozen_string_literal: true

module Patches
  module RubyLLM
    module Providers
      module OpenRouterPatch
        DEFAULT_OPENROUTER_TTS_RESPONSE_FORMAT = "pcm"

        private

        def render_speech_payload(input, model:, voice: nil, **options)
          provider_payload = options.delete(:provider_options)
          response_format = options.key?(:response_format) ? options[:response_format] : DEFAULT_OPENROUTER_TTS_RESPONSE_FORMAT
          resolved_voice = voice || default_openrouter_tts_voice(model)

          payload = {
            model:,
            input:,
            response_format:
          }
          payload[:voice] = resolved_voice if resolved_voice.present?
          payload.merge!(options.compact)

          payload[:provider] = provider_payload if provider_payload.present?
          payload
        end

        def default_openrouter_tts_voice(model)
          return ::Patches::RubyLLM::Providers::OpenAIPatch::DEFAULT_TTS_VOICE if model.to_s.start_with?("openai/")

          nil
        end
      end
    end
  end
end
