module JobChatSupport
  extend ActiveSupport::Concern

  def show_message_placeholder(chat)
    Turbo::StreamsChannel.broadcast_update_to(
      chat,
      target: "message-placeholder-slot-#{chat.id}",
      content: Chats::MessagePlaceholderComponent.new(chat:, current_character: chat.character),
    )
  end

  def broadcast_error(chat, error)
    message = chat.messages.create!(role: :error, content: error)

    sleep 0.3

    broadcast_message(message)
  end

  def broadcast_message(message)
    Turbo::StreamsChannel.broadcast_before_to(
      message.chat,
      target: "message-placeholder-slot-#{message.chat.id}",
      content: Chats::MessageComponent.new(message:, current_character: message.chat.character),
    )

    remove_message_placeholder(message.chat)
  end

  def remove_message_placeholder(chat)
    Turbo::StreamsChannel.broadcast_update_to(
      chat,
      target: "message-placeholder-slot-#{chat.id}",
      content: "",
    )
  end
end
