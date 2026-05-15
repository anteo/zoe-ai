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
    message = chat.messages.create!(role: :error, content: error)

    sleep 0.3

    remove_message_placeholder(chat)

    Turbo::StreamsChannel.broadcast_append_to(
      chat,
      target: "chat-messages",
      content: Chats::MessageComponent.new(message:, current_character: chat.character),
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
