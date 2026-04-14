Rails.application.config.after_initialize do
  CloseChatsJob.perform_later if Chat.stale.exists?
end
