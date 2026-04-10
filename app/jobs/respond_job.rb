# frozen_string_literal: true

class RespondJob < ApplicationJob
  def perform(chat)
    ai_chat = AI::Zoe.find(chat.id)
    show_message_placeholder(ai_chat)

    ai_chat.on_end_message do
      message = ai_chat.message
      schedule_message(ai_chat, message) if message.assistant?
    end.complete
  rescue => e
    broadcast_error(chat, e.message)
    raise
  end

  private

  def schedule_message(chat, message)
    if execution.cancelled?
      message.destroy
      return
    end

    return unless message.visible?

    sentences = AI::SentenceSplitter.new(message.content).sentences
    TypeSentenceJob.perform_later(chat, message, sentences, true)
  end
end
