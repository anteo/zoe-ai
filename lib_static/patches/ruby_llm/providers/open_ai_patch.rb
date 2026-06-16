# frozen_string_literal: true

module Patches
  module RubyLLM
    module Providers
      module OpenAIPatch
        DEFAULT_TTS_VOICE = "alloy"

        private

        def speech_url(model: nil)
          "audio/speech"
        end

        def render_speech_payload(input, model:, voice: nil, **options)
          {
            model:,
            input:,
            voice: voice || DEFAULT_TTS_VOICE
          }.merge(options.compact)
        end

        def parse_speech_response(response, model:)
          ::RubyLLM::Speech.new(
            data: response.body,
            model:,
            mime_type: response.headers["content-type"]
          )
        end
      end
    end
  end
end
