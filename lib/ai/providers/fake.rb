require "digest"
require "set"

module AI
  module Providers
    class Fake < RubyLLM::Provider
      @empty_once_keys = Set.new

      class << self
        attr_reader :empty_once_keys

        def local?
          true
        end
      end

      def api_base
        "fake://local"
      end

      def complete(messages, **)
        sleep(1 + rand(5))

        input = last_user_input(messages)

        RubyLLM::Message.new(
          role: :assistant,
          content: response_text(messages, input)
        )
      end

      def list_models
        [
          RubyLLM::Model::Info.new(
            id: "fake-dev",
            name: "Fake Dev",
            provider: slug,
            family: "fake",
            context_window: 128_000,
            max_output_tokens: 8_192,
            modalities: { input: [ "text" ], output: [ "text" ] },
            capabilities: %w[function_calling streaming structured_output],
            metadata: { source: "local", env: "development" }
          )
        ]
      end

      private

      def last_user_input(messages)
        messages.reverse.find { it.role == :user }&.content.to_s
      end

      def response_text(messages, input)
        case input
        when "empty_always"
          ""
        when "empty_once"
          empty_once_response(messages, input)
        else
          input
        end
      end

      def empty_once_response(messages, input)
        key = Digest::SHA256.hexdigest(
          messages.map { |message| [ message.role, message.content.to_s, message.tool_call_id ] }.inspect
        )

        return input if self.class.empty_once_keys.include?(key)

        self.class.empty_once_keys << key
        ""
      end
    end
  end
end
