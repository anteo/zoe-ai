class ApplicationJob < ActiveJob::Base
  include MissionControl

  before_perform :sync_settings
  around_perform :with_request_store

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  def show_message_placeholder(chat)
    Turbo::StreamsChannel.broadcast_append_to(
      chat,
      target: "chat-messages",
      content: Chat::MessagePlaceholderComponent.new(chat:, current_character: chat.character),
    )
  end

  def broadcast_error(chat, error)
    Turbo::StreamsChannel.broadcast_replace_to(
      chat,
      target: "message-placeholder-#{chat.id}",
      content: UI::ErrorComponent.new(current_character: chat.character, chat:, error:),
    )
  end

  def broadcast_message(message)
    Turbo::StreamsChannel.broadcast_replace_to(
      message.chat,
      target: "message-placeholder-#{message.chat.id}",
      content: Chat::MessageComponent.new(message:, current_character: message.chat.character),
    )
  end

  def remove_message_placeholder(chat)
    Turbo::StreamsChannel.broadcast_remove_to(
      chat,
      target: "message-placeholder-#{chat.id}",
    )
  end

  private

  def sync_settings
    Setting.sync_hooks_if_stale!(context: { source: :job, job: self.class.name })
  end

  def with_request_store
    return yield unless defined?(RequestStore)

    RequestStore.begin!
    yield
  ensure
    RequestStore.end!
    RequestStore.clear!
  end
end
