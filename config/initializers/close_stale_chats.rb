Rails.application.config.after_initialize do
  if Rails.env.development? && Chat.column_names.include?("dream") && Chat.stale.exists?
    CloseStaleChatsJob.perform_later
  end
end
