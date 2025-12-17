# frozen_string_literal: true

class TypeSentenceJob < ApplicationJob
  limits_concurrency key: ->(chat, *) { "type_sentence_#{chat.id}" }

  def perform(chat, message, sentences, first = false)
    return if sentences.empty?

    show_message_placeholder(chat) unless first

    sentence = sentences.shift

    sleep 1 + sentence.length / 50

    display_message = message.dup
    display_message.created_at = message.created_at
    display_message.content = sentence.to_s

    display_message.attachments.attach(message.attachments.blobs) if first

    broadcast_message(display_message)

    show_message_placeholder(chat) if RespondJob.get_running_execution(chat)

    TypeSentenceJob.perform_later(chat, message, sentences, false) if sentences.any?
  end
end
