# frozen_string_literal: true

module Patches
  module RubyLLM
    module ProviderPatch
      def speak(input, model:, voice: nil, **options)
        payload = render_speech_payload(input, model:, voice:, **options)
        response = @connection.post(speech_url(model:), payload)
        parse_speech_response(response, model:).with_response_format(payload[:response_format]).normalized
      end

      private

      def speech_url(model: nil)
        raise NotImplementedError, "#{self.class.name} does not support speech generation"
      end

      def render_speech_payload(...)
        raise NotImplementedError, "#{self.class.name} does not support speech generation"
      end

      def parse_speech_response(...)
        raise NotImplementedError, "#{self.class.name} does not support speech generation"
      end
    end
  end
end
