class ChatTriggeredJob < ApplicationJob
  include JobChatSupport

  attr_reader :chat, :trigger_message_id

  def perform(chat, trigger_message_id, ...)
    @chat = chat
    @trigger_message_id = trigger_message_id

    run(...)
  end

  private

  def cancelled?
    execution&.cancelled? || chat.stale_trigger_message?(trigger_message_id)
  end

  def run(*)
    raise NotImplementedError, "#{self.class.name} must implement #run"
  end
end
