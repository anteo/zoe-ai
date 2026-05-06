# frozen_string_literal: true

module Patches
  module RubyLLM
    module Providers
      module DeepSeekPatch
        extend ActiveSupport::Concern

        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil,
                           thinking: nil, tool_prefs: nil)
          payload = super
          return payload unless schema

          payload[:messages] = messages_with_schema_instruction(payload[:messages], schema)
          payload[:response_format] = { type: "json_object" }
          payload
        end

        private

        def messages_with_schema_instruction(messages, schema)
          updated_messages = messages.map(&:dup)
          instruction = structured_output_instruction(schema)
          existing_system_index = updated_messages.index do |message|
            message[:role] == "system" && message[:content].is_a?(String)
          end

          return updated_messages.prepend({ role: "system", content: instruction }) unless existing_system_index

          updated_messages[existing_system_index] = updated_messages[existing_system_index].merge(
            content: [updated_messages[existing_system_index][:content], instruction].join("\n\n")
          )
          updated_messages
        end

        def structured_output_instruction(schema)
          <<~TEXT.squish
            Return a single valid JSON object that matches the required schema exactly.
            This response must be valid json.
            Do not wrap the response in Markdown or code fences.
            Do not add any text before or after the JSON object.
            Follow this JSON schema exactly: #{JSON.generate(schema[:schema])}
          TEXT
        end
      end
    end
  end
end
