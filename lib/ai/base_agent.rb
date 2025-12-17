module AI
  class BaseAgent < RubyLLM::Agent
    class << self
      private

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
