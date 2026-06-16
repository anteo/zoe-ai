# frozen_string_literal: true

module Patches
  module RubyLLM
    module ConfigurationPatch
      DEFAULT_TTS_MODEL = "gpt-4o-mini-tts"

      def default_tts_model
        @default_tts_model || DEFAULT_TTS_MODEL
      end

      def default_tts_model=(value)
        value = nil if value.is_a?(String) && value.strip.empty?
        @default_tts_model = value
      end
    end
  end
end
