require "digest"
require "securerandom"
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

      def complete(messages, tools: {}, **)
        input = last_user_input(messages)
        request = fake_tool_request(input)
        fake_tool_name = registered_fake_tool_name(tools)

        if request && fake_tool_completed?(messages)
          return RubyLLM::Message.new(
            role: :assistant,
            content: "Fake tool completed."
          )
        end

        if request && fake_tool_name.present?
          arguments = {}
          arguments[:instructions] = request if request.present?
          tool_call = RubyLLM::ToolCall.new(
            id: SecureRandom.uuid,
            name: fake_tool_name,
            arguments:
          )

          return RubyLLM::Message.new(
            role: :assistant,
            content: nil,
            tool_calls: { tool_call.id => tool_call }
          )
        end

        sleep(1 + rand(5))

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
        raw_input = messages.reverse.find { it.role == :user }&.content.to_s
        Message.humanize_content(raw_input)
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

      def fake_tool_request(input)
        match = input.match(/\Afake_tool(?:\s+)?(.*)\z/m)
        return unless match

        match[1].to_s.strip
      end

      def fake_tool_completed?(messages)
        trailing_messages(messages).any? do |message|
          message.role == :tool && message.tool_call_id.present?
        end
      end

      def registered_fake_tool_name(tools)
        tools.find { |_, tool| tool.is_a?(AI::Tools::FakeTool) }&.first&.to_s
      end

      def trailing_messages(messages)
        index = messages.rindex { it.role == :user }
        return messages if index.nil?

        messages[(index + 1)..] || []
      end
    end
  end
end
