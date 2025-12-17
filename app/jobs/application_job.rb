class ApplicationJob < ActiveJob::Base
  include MissionControl

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  def show_message_placeholder(chat)
    Turbo::StreamsChannel.broadcast_append_to(
      chat,
      target: "chat-messages",
      content: MessagePlaceholderComponent.new(chat:, current_user: chat.user),
    )
  end

  def broadcast_error(chat, error)
    Turbo::StreamsChannel.broadcast_replace_to(
      chat,
      target: "message-placeholder-#{chat.id}",
      content: ErrorComponent.new(current_user: chat.user, chat:, error:),
    )
  end

  def broadcast_message(message)
    Turbo::StreamsChannel.broadcast_replace_to(
      message.chat,
      target: "message-placeholder-#{message.chat.id}",
      content: MessageComponent.new(message:, current_user: message.chat.user),
    )
  end

  def remove_message_placeholder(chat)
    Turbo::StreamsChannel.broadcast_remove_to(
      chat,
      target: "message-placeholder-#{chat.id}",
    )
  end
end
