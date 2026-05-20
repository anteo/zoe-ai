class RespondJob < ApplicationJob
  include JobChatSupport

  limits_concurrency to: 1,
                     key: ->(chat) { "respond_chat_#{chat.id}" }

  def perform(chat)
    ensure_chat_model!(chat)
    show_message_placeholder(chat)
    ai_chat = AI::Agents::Zoe.find(chat.id)

    ai_chat.after_message do
      message = ai_chat.message
      schedule_message(chat, message) if message.assistant?
    end.complete
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

  def schedule_message(chat, message)
    if execution.cancelled?
      message.destroy
      return
    end

    unless message.replayable_for_llm?
      message.destroy
      return
    end

    return unless message.visible?

    Turbo::StreamsChannel.broadcast_replace_to(
      chat,
      target: "token-usage-gauge-#{chat.id}",
      content: Chats::TokenUsageGaugeComponent.new(chat:),
    )

    chunks = AI::SentenceSplitter.new(message.content).chunks
    TypeSentenceJob.perform_later(chat, message, chunks, true)
    ExtractFactsJob.perform_later(chat)
  end
end
