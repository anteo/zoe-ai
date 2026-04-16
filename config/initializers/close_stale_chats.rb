Rails.application.config.after_initialize do
  CloseStaleChatsJob.perform_later if Chat.stale.exists?
end
