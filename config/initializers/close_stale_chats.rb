Rails.application.config.after_initialize do
  CloseStaleChatsJob.perform_later if Rails.env.development? && Chat.stale.exists?
end
