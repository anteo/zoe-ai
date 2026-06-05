class DeliverPendingMessageJob < ApplicationJob
  include JobChatSupport

  limits_concurrency to: 1,
                     key: ->(pending_message_id) { "deliver_pending_message_#{pending_message_id}" },
                     on_conflict: :discard

  def perform(pending_message_id)
    message = nil
    pending_message = nil

    PendingMessage.transaction do
      pending_message = PendingMessage.with_attached_attachments.lock.find_by(id: pending_message_id)
      next unless pending_message

      target_chat = immediate_target_chat_for(pending_message)
      next unless target_chat

      message = pending_message.deliver_to!(target_chat)
      pending_message.destroy!
    end

    if message
      broadcast_message(message)
    elsif pending_message
      broadcast_draft_chat(pending_message)
    end
  end

  private

  def immediate_target_chat_for(pending_message)
    user = pending_message.user || pending_message.source_message&.chat&.user
    return unless user

    user.chats
        .dreaming(false)
        .closed(false)
        .where(character: pending_message.recipient, partner: pending_message.partner)
        .order(created_at: :desc, id: :desc)
        .first
  end

  def broadcast_draft_chat(pending_message)
    user = pending_message.user || pending_message.source_message&.chat&.user
    return unless user

    component = Chats::ChatComponent.new(
      chat: Chat.new(user:, character: pending_message.recipient, partner: pending_message.partner)
    )

    Turbo::StreamsChannel.broadcast_remove_to(
      [ user, pending_message.recipient, pending_message.partner, :pending_messages ],
      target: component.draft_empty_state_id,
    )

    Chats::ChatComponent.display_messages(pending_message).each do |message|
      Turbo::StreamsChannel.broadcast_append_to(
        [ user, pending_message.recipient, pending_message.partner, :pending_messages ],
        target: component.draft_messages_id,
        content: Chats::MessageComponent.new(message:, current_character: pending_message.recipient),
      )
    end
  end
end
