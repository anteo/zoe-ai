class StopTypingJob < ChatTriggeredJob
  def run
    return if cancelled?

    remove_message_placeholder(chat)
    broadcast_tts_stop(chat)

    TypeSentenceJob.cancel(chat)
    SpeakMessageJob.cancel(chat)
    RespondJob.cancel(chat)
  end
end
