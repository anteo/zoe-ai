class StopTypingJob < ApplicationJob
  include JobChatSupport

  def perform(chat, trigger_message_id = nil)
    return if chat.stale_trigger_message?(trigger_message_id)

    remove_message_placeholder(chat)

    TypeSentenceJob.cancel(chat)
    RespondJob.cancel(chat)
  end
end
