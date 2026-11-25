module AI
  module Tools
    class DelegateTask < Tool
      description <<~TEXT.squish
        Choose an available specialist when the user's goal or the conversation context calls for
        its capabilities, even when the user does not mention an agent. Give it the context needed
        for the task and answer with its findings. Provide the agent for a new conversation or
        conversation_id to continue a related task. If delegation fails, explain the returned error.
      TEXT

      params do
        string :task, description: "The complete task and context for the agent", required: true
        string :agent, description: "Agent key, id:NUMBER, or exact name from the available profiles. Required for a new conversation.", required: false
        integer :conversation_id, description: "Agent conversation ID for a follow-up. Omit when selecting an agent for a new conversation.", required: false
      end

      def name
        "delegate_task"
      end

      def description
        profiles = ::Agent.delegatable(current_user).order(:id).pluck(:id, :key, :name, :description).map do |id, key, name, description|
          { agent: key || "id:#{id}", name:, description: }
        end
        "#{super} Available agents: #{profiles.to_json}."
      end

      def execute(task:, agent: nil, conversation_id: nil)
        fail! "Provide a task to delegate." unless task.is_a?(String) && task.strip.present?

        if conversation_id.nil?
          fail! "Select an available agent for a new conversation." unless agent.is_a?(String) && agent.present?

          profile = find_profile(agent)
        else
          fail! "Provide only the conversation ID to continue an existing conversation." unless agent.nil?

          conversation = find_conversation(conversation_id)
          profile = ::Agent.active.custom.find_by(id: conversation.agent_id)
        end
        fail! "Delegation profile is unavailable." unless profile

        JSON.generate(AgentDelegation.new(chat).dispatch(task:, profile:, conversation:))
      end

      private

      def find_profile(selection)
        profiles = ::Agent.delegatable(current_user)
        if (id = selection[/\Aid:(\d+)\z/, 1])
          profiles.find_by(id:)
        else
          profiles.find_by(key: selection) || profiles.find_by(name: selection)
        end
      end

      def find_conversation(id)
        if id.is_a?(Integer) && id.positive?
          conversation = ::AgentConversation.for_chat_identity(chat).find_by(id:)
        end
        conversation || fail!("Agent conversation is unavailable.")
      end
    end
  end
end
