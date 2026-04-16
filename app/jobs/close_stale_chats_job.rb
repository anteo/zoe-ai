class CloseStaleChatsJob < ApplicationJob
  def perform
    Chat.stale.find_each do |chat|
      CloseChatJob.perform_later(chat)
    end
  end
end
