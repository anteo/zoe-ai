class RespondJob < ChatTriggeredJob
  retry_on AI::EmptyAssistantResponseError, wait: 0.seconds, attempts: 4 do |job, error|
    chat = job.arguments.first
    job.broadcast_error(chat, error.message)
  end

  limits_concurrency to: 1,
                     key: ->(chat, *) { "respond_chat_#{chat.id}" }

  def self.waiting_for_reply?(chat, delegated_job_ids:)
    trigger_message_id = chat.latest_user_message_id
    return false unless trigger_message_id

    executions = get_running_executions(chat).reject(&:cancelled?)
    (executions + get_queued_executions(chat)).any? do |execution|
      job = execution.job
      job.arguments.fetch("arguments")[1] == trigger_message_id && !delegated_job_ids.include?(job.active_job_id)
    end
  end

  def run
    return if cancelled?

    chat.agent_runs.reconcile_interrupted!
    show_message_placeholder(chat) if executions == 1
    ensure_chat_model!(chat)
    ai_chat = AI::Agents::Zoe.find(chat.id)
    ai_chat.agent_run_trigger_message_id = trigger_message_id
    ai_chat.agent_run_job_owner = { respond_job_id: job_id, respond_job_execution_id: execution&.id }
    add_active_agent_runs(ai_chat)

    catch(:cancelled_response) do
      ai_chat.before_tool_call do |call|
        remove_message_placeholder(chat) if call.name == "delegate_task" && !cancelled?
      end
      ai_chat.after_message do
        message = ai_chat.message
        schedule_message(message) if message.assistant?
      end.complete
    end
  rescue AI::EmptyAssistantResponseError
    raise
  rescue => e
    broadcast_error(chat, e.message)
    raise
  end

  private

  def add_active_agent_runs(ai_chat)
    runs = chat.agent_runs.shown_in_chat.running
    runs = runs.where(local_workspace: false) unless chat.user.admin?
    active = runs.order(id: :desc).limit(10).map do |run|
      {
        conversation_id: run.agent_conversation_id, run_id: run.id, agent: run.agent_name,
        task: run.task.truncate(300), status: run.workspace_status || run.status
      }
    end
    return if active.empty?

    ai_chat.with_runtime_instructions(<<~INSTRUCTIONS, append: true)
      These specialist runs are active in this chat. Their results will be posted automatically.
      Use agent_history for current status. Answer any new request in the meantime.
      Active runs: #{active.to_json}
    INSTRUCTIONS
  end

  def ensure_chat_model!(chat)
    return if chat.model_id.present?
    resolved_chat = AI::Agents::Zoe.build_chat(character: chat.character, partner: chat.partner, user: chat.user)
    model = resolved_chat.resolved_model
    return if model.blank?

    chat.with_lock do
      chat.update_column(:model_id, model.id) if chat.model_id.blank?
    end
  rescue AI::ModelNotConfiguredError
    nil
  end

  def schedule_message(message)
    if cancelled?
      message.destroy
      throw :cancelled_response
    end

    Turbo::StreamsChannel.broadcast_replace_to(
      chat,
      target: "token-usage-gauge-#{chat.id}",
      content: Chats::TokenUsageGaugeComponent.new(chat:),
    )

    chunks = AI::SentenceSplitter.new(message.content).chunks

    # Speak the entire message for now instead of speaking in chunks.
    SpeakMessageJob.perform_later(chat, trigger_message_id, message, message.content) if AI.tts_enabled? && message.tts_enabled?
    TypeSentenceJob.perform_later(chat, trigger_message_id, message, chunks, true)
    ExtractFactsJob.perform_later(chat)
  end
end
