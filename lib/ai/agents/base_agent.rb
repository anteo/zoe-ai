module AI
  module Agents
    class BaseAgent < RubyLLM::Agent
      class << self
        # Override to enable ERB trim mode for cleaner template output
        def render_prompt(name, chat:, inputs:, locals:)
          path = prompt_path_for(name)
          unless File.exist?(path)
            raise RubyLLM::PromptNotFoundError,
                  "Prompt file not found for #{self}: #{path}. Create the file or use inline instructions."
          end

          resolved_locals = resolve_prompt_locals(locals, runtime: runtime_context(chat:, inputs:), chat:, inputs:)
          ERB.new(File.read(path), trim_mode: "-").result_with_hash(resolved_locals)
        end

        def build_chat(**kwargs)
          _, chat_options = partition_inputs(kwargs)
          resolved_chat_model.new(**kwargs, **chat_kwargs, **chat_options)
        end

        private

        def apply_instructions(chat_object, runtime, inputs:, persist:)
          return super unless chat_object.respond_to?(:messages_association)
          return if chat_object.messages_association.where(role: :system).exists?

          # First call: render and always persist for LLM cache stability
          value = resolved_instructions_value(chat_object, runtime, inputs:)
          return if value.nil?

          chat_object.with_instructions(value)
        end

        def apply_tools(llm_chat, runtime)
          tools_to_apply = Array(evaluate(tools, runtime))
          tools_to_apply = tools_to_apply.map { it.is_a?(Class) ? it.new(runtime.chat) : it }
          llm_chat.with_tools *tools_to_apply unless tools_to_apply.empty?
        end

        def resolve_prompt_locals(locals, runtime:, chat:, inputs:)
          super.tap do |base|
            base[:runtime] = runtime
            base[:helpers] = AI::PromptController.new.helpers
          end
        end
      end
    end
  end
end
