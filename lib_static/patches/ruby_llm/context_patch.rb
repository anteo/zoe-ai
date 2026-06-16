# frozen_string_literal: true

module Patches
  module RubyLLM
    module ContextPatch
      def speak(*args, **kwargs, &block)
        kwargs[:context] ||= self
        ::RubyLLM::Speech.speak(*args, **kwargs, &block)
      end

      alias tts speak
    end
  end
end
