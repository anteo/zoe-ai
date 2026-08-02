# frozen_string_literal: true

require "securerandom"

module AI
  module Providers
    # Ollama Cloud API integration.
    # Hosted OpenAI-compatible endpoints at https://ollama.com/v1.
    class OllamaCloud < RubyLLM::Providers::Ollama
      def api_base
        @config.ollama_cloud_api_base || "https://ollama.com/v1"
      end

      def headers
        { "Authorization" => "Bearer #{@config.ollama_cloud_api_key}" }
      end

      def complete(...)
        namespace_tool_call_ids(super)
      end

      # Ollama Cloud supports JSON mode, but not schema-constrained responses.
      # Keep the schema attached to the RubyLLM chat so its response normalizer
      # still parses the JSON string, while prompting the model with the schema.
      def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil,
                         thinking: nil, tool_prefs: nil)
        payload = super
        return payload unless schema

        payload[:response_format] = { type: "json_object" }
        add_schema_instruction(payload[:messages], schema.fetch(:schema))
        payload
      end

      class << self
        def slug
          "ollama_cloud"
        end

        def configuration_options
          %i[ollama_cloud_api_base ollama_cloud_api_key]
        end

        def configuration_requirements
          %i[ollama_cloud_api_key]
        end

        def local?
          false
        end

        def assume_models_exist?
          true
        end

        def capabilities
          RubyLLM::Providers::Ollama::Capabilities
        end
      end

      private

      def namespace_tool_call_ids(message)
        return message if message&.tool_calls.blank?

        response_body = message.raw&.body
        namespace = response_body["id"] if response_body.is_a?(Hash)
        namespace = SecureRandom.uuid if namespace.blank?

        tool_calls = message.tool_calls.values.to_h do |tool_call|
          id = "#{namespace}:#{tool_call.id}"
          [
            id,
            RubyLLM::ToolCall.new(
              id:,
              name: tool_call.name,
              arguments: tool_call.arguments,
              thought_signature: tool_call.thought_signature
            )
          ]
        end

        RubyLLM::Message.new(
          role: message.role,
          content: message.content,
          model_id: message.model_id,
          tool_calls:,
          tool_call_id: message.tool_call_id,
          raw: message.raw,
          thinking: message.thinking,
          tokens: message.tokens
        )
      end

      def add_schema_instruction(messages, schema)
        instruction = <<~PROMPT.strip
          Return only a valid JSON object matching this JSON Schema exactly:
          #{JSON.generate(schema)}
        PROMPT
        system_message = messages.find do |message|
          message[:role].in?(%w[system developer]) && message[:content].is_a?(String)
        end

        if system_message
          system_message[:content] = "#{system_message[:content]}\n\n#{instruction}"
        else
          messages.unshift(role: "system", content: instruction)
        end
      end
    end
  end
end
