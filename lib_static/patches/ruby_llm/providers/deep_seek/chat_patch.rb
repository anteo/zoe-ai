# frozen_string_literal: true

module Patches
  module RubyLLM
    module Providers
      module DeepSeek
        module ChatPatch
          extend ActiveSupport::Concern

          class_methods do
            def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil,
                               thinking: nil, tool_prefs: nil)
              payload = RubyLLM::Providers::OpenAI::Chat.render_payload(
                messages,
                tools:,
                temperature:,
                model:,
                stream:,
                schema:,
                thinking:,
                tool_prefs:
              )

              return payload unless schema

              payload[:messages] = messages_with_schema_instruction(payload[:messages], schema)
              payload[:response_format] = { type: "json_object" }
              payload
            end

            def messages_with_schema_instruction(messages, schema)
              instruction = structured_output_instruction(schema)
              existing_system_index = messages.index do |message|
                message[:role] == "system" && message[:content].is_a?(String)
              end

              return messages.prepend({ role: "system", content: instruction }) unless existing_system_index

              messages[existing_system_index] = messages[existing_system_index].merge(
                content: [ messages[existing_system_index][:content], instruction ].join("\n\n")
              )
              messages
            end

            def structured_output_instruction(schema)
              <<~TEXT.squish
                Return a single valid JSON object that matches the required schema exactly.
                Do not wrap the response in Markdown or code fences.
                Do not add any text before or after the JSON object.
                Required JSON schema: #{JSON.generate(schema[:schema])}
              TEXT
            end
          end
        end
      end
    end
  end
end
