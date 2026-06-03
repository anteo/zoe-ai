class CloseChatJob < ApplicationJob
  def perform(chat)
    if chat.messages.empty?
      chat.destroy
    else
      chat.update!(closed: true, closed_at: Time.current)
      ChatChannel.broadcast_to(chat, type: "closed")
      SummarizeChatJob.perform_later(chat) if chat.summary.nil?
    end
  end
end
