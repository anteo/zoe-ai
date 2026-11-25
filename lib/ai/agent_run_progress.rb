module AI
  module AgentRunProgress
    def self.broadcast(run)
      Turbo::StreamsChannel.broadcast_action_to(
        run.chat,
        action: :reload_agent_runs,
        target: Chats::AgentRunsComponent.frame_id(run.chat_id, run.trigger_message_id),
        attributes: { data: { agent_conversation_id: run.agent_conversation_id } },
        render: false,
      )
    rescue StandardError => error
      Rails.logger.warn("Failed to broadcast progress for agent run #{run.id}: #{error.class}")
    end
  end
end
