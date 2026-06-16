# frozen_string_literal: true

module Patches
  module RubyLLMPatch
    extend ActiveSupport::Concern

    prepended do
      autoload :Speech, "ruby_llm/speech"
    end

    class_methods do
      def speak(...)
        ::RubyLLM::Speech.speak(...)
      end

      alias tts speak
    end
  end
end
