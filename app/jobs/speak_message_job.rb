require "securerandom"

class SpeakMessageJob < ChatTriggeredJob
  limits_concurrency key: ->(chat, *) { "speak_message_#{chat.id}" }

  def run(message, text)
    return if cancelled? || !AI.tts_enabled? || !message.tts_enabled?

    style = message.tts_style
    speech = AI.speak(
      text,
      model: Setting.ai.models.default_tts_model,
      voice: Setting.ai.tts.voice,
      style:
    )

    return if cancelled?

    token = SecureRandom.urlsafe_base64(24)
    Rails.cache.write(
      AI::Speech.cache_key(token),
      {
        data: speech.data,
        mime_type: speech.mime_type
      },
      expires_in: 30.minutes
    )

    broadcast_tts_audio(chat, {
      message_id: message.id,
      mime_type: speech.mime_type,
      token:
    })
  end
end
