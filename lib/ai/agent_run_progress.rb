module AI
  module AgentRunProgress
    def self.stream_options(run, url:)
      {
        target: Chats::ChatComponent.active_runs_id(run.chat_id),
        data: { frame_id: Chats::AgentRunComponent.frame_id(run.id), url:, agent_conversation_id: run.agent_conversation_id }
      }
    end

    def self.broadcast(run)
      url = Rails.application.routes.url_helpers.agent_run_chat_path(run.chat_id, run_id: run.id)
      options = stream_options(run, url:)
      Turbo::StreamsChannel.broadcast_action_to(
        run.chat,
        action: :reload_agent_run,
        target: options.fetch(:target),
        attributes: { data: options.fetch(:data) },
        render: false,
      )
    rescue StandardError => error
      Rails.logger.warn("Failed to broadcast progress for agent run #{run.id}: #{error.class}")
    end
  end
end
