module JobChatSupport
  extend ActiveSupport::Concern

  def show_message_placeholder(chat)
    Turbo::StreamsChannel.broadcast_append_to(
      chat,
      target: "chat-messages",
      content: Chats::MessagePlaceholderComponent.new(chat:, current_character: chat.character),
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
      content: Chats::MessageComponent.new(message:, current_character: message.chat.character),
    )
  end

  def remove_message_placeholder(chat)
    Turbo::StreamsChannel.broadcast_remove_to(
      chat,
      target: "message-placeholder-#{chat.id}",
    )
  end
end
