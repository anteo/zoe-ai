module AI
  module Agents
    class BaseAgent < RubyLLM::Agent
      class << self
        def agent_key(key = nil)
          return @agent_key if key.nil?
          @agent_key = key.to_s
        end

        def agent_config
          return nil unless @agent_key
          ::Agent.find_by(key: @agent_key)
        end

        def chat_kwargs
          config = agent_config
          return super unless config&.model
          super.merge(model: config.model.model_id)
        end

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
          resolved_chat_model.new(**kwargs, **chat_kwargs, **chat_options).tap do |chat|
            chat.send(:resolve_model_from_strings)
          end
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

          config = agent_config
          if config
            mcp = config.mcp_servers.active.flat_map(&:mcp_tools)
            tools_to_apply += mcp
          end

          llm_chat.with_tools(*tools_to_apply) unless tools_to_apply.empty?
        end

        def apply_temperature(llm_chat)
          config = agent_config
          value = config&.temperature.presence || temperature
          llm_chat.with_temperature(value) unless value.nil?
        end

        def apply_thinking(llm_chat)
          config = agent_config
          if config&.thinking_effort.present?
            llm_chat.with_thinking(effort: config.thinking_effort, budget: config.thinking_budget)
          else
            super
          end
        end

        def resolved_instructions_value(chat_object, runtime, inputs:)
          config = agent_config
          return config.instructions if config&.instructions.present?
          super
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
