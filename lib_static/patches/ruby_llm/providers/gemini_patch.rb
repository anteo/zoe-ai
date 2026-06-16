# frozen_string_literal: true

module Patches
  module RubyLLM
    module Providers
      module GeminiPatch
        DEFAULT_TTS_VOICE = "Kore"

        private

        def speech_url(model: nil)
          "models/#{model}:generateContent"
        end

        def render_speech_payload(input, model:, voice: nil, **options)
          generation_config = {
            responseModalities: [ "AUDIO" ],
            speechConfig: {
              voiceConfig: {
                prebuiltVoiceConfig: {
                  voiceName: voice || DEFAULT_TTS_VOICE
                }
              }
            }
          }
          generation_config[:temperature] = options[:temperature] if options.key?(:temperature)
          generation_config[:maxOutputTokens] = options[:max_output_tokens] if options[:max_output_tokens]

          {
            contents: [
              {
                role: "user",
                parts: [ { text: input } ]
              }
            ],
            generationConfig: generation_config,
            model:
          }.tap do |payload|
            payload[:safetySettings] = options[:safety_settings] if options[:safety_settings]
          end
        end

        def parse_speech_response(response, model:)
          inline_data = response.body.dig("candidates", 0, "content", "parts", 0, "inlineData")
          raise ::RubyLLM::Error.new(nil, "Unexpected response format from Gemini speech API") unless inline_data

          audio_data = inline_data["data"]
          raise ::RubyLLM::Error.new(nil, "Gemini speech response did not include audio data") unless audio_data

          ::RubyLLM::Speech.new(
            data: Base64.decode64(audio_data),
            model:,
            mime_type: inline_data["mimeType"]
          )
        end
      end
    end
  end
end
