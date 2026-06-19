class TypeSentenceJob < ChatTriggeredJob
  limits_concurrency key: ->(chat, *) { "type_sentence_#{chat.id}" }

  def run(message, chunks, first = false)
    return if chunks.empty?

    show_message_placeholder(chat) unless first

    chunk = chunks.shift

    sleep 1 + chunk.length / 50
    return if cancelled?

    display_message = message.dup
    display_message.created_at = message.created_at
    display_message.content = chunk.to_s

    display_message.attachments.attach(message.attachments.blobs) if first

    broadcast_message(display_message)

    show_message_placeholder(chat) if RespondJob.running_for?(chat)

    TypeSentenceJob.perform_later(chat, trigger_message_id, message, chunks, false) if chunks.any?
  end
end
