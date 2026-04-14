class CloseChatsJob < ApplicationJob
  def perform
    Chat.stale.find_each do |chat|
      if chat.messages.empty?
        chat.destroy
      else
        chat.update!(closed: true)
        ChatChannel.broadcast_to(chat, type: "closed")
        SummarizeChatJob.perform_later(chat) if chat.summary.nil?
      end
    end
  end
end
