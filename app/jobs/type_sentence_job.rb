# frozen_string_literal: true

class TypeSentenceJob < ApplicationJob
  include JobChatSupport

  limits_concurrency key: ->(chat, *) { "type_sentence_#{chat.id}" }

  def perform(chat, message, chunks, first = false)
    return if chunks.empty?

    show_message_placeholder(chat) unless first

    chunk = chunks.shift

    sleep 1 + chunk.length / 50
    return if execution&.cancelled?

    display_message = message.dup
    display_message.created_at = message.created_at
    display_message.content = chunk.to_s

    display_message.attachments.attach(message.attachments.blobs) if first

    broadcast_message(display_message)

    show_message_placeholder(chat) if RespondJob.get_running_execution(chat)

    TypeSentenceJob.perform_later(chat, message, chunks, false) if chunks.any?
  end
end
