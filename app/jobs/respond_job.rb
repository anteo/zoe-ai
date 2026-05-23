class RespondJob < ApplicationJob
  include JobChatSupport

  retry_on AI::EmptyAssistantResponseError, wait: 0.seconds, attempts: 4 do |job, error|
    chat = job.arguments.first
    job.broadcast_error(chat, error.message)
  end

  limits_concurrency to: 1,
                     key: ->(chat, *) { "respond_chat_#{chat.id}" }

  def perform(chat, trigger_message_id)
    return if chat.stale_trigger_message?(trigger_message_id)

    ensure_chat_model!(chat)
    show_message_placeholder(chat) if executions == 1
    ai_chat = AI::Agents::Zoe.find(chat.id)

    ai_chat.after_message do
      message = ai_chat.message
      schedule_message(chat, message, trigger_message_id) if message.assistant?
    end.complete
  rescue AI::EmptyAssistantResponseError
    raise
  rescue => e
    broadcast_error(chat, e.message)
    raise
  end

  private

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

  def schedule_message(chat, message, trigger_message_id)
    if execution.cancelled? || chat.stale_trigger_message?(trigger_message_id)
      message.destroy
      return
    end

    Turbo::StreamsChannel.broadcast_replace_to(
      chat,
      target: "token-usage-gauge-#{chat.id}",
      content: Chats::TokenUsageGaugeComponent.new(chat:),
    )

    chunks = AI::SentenceSplitter.new(message.content).chunks
    TypeSentenceJob.perform_later(chat, message, chunks, trigger_message_id, true)
    ExtractFactsJob.perform_later(chat)
  end
end
