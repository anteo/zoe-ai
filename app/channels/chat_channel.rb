class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_for chat
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def user_typing
    return unless RespondJob.running_for?(chat) ||
                  TypeSentenceJob.running_for?(chat) ||
                  SpeakMessageJob.running_for?(chat)

    StopTypingJob.perform_now(chat, chat.latest_user_message_id)
  end

  def update_memorize(data)
    chat.update!(memorize: ActiveModel::Type::Boolean.new.cast(data["memorize"]))
    ChatChannel.broadcast_to(chat, type: "memorize_updated", memorize: chat.memorize)
  end

  def stop_tts
    chat.messages.where(id: chat.latest_user_message_id, role: "user").update_all(tts_enabled: false)
    SpeakMessageJob.cancel(chat)
    broadcast_tts_stop(chat)
  end

  private

  def chat
    @chat ||= Chat.find(params[:chat_id])
  end
end
