class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_for chat
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def user_typing
    return unless RespondJob.running_for?(chat) || TypeSentenceJob.running_for?(chat)

    StopTypingJob.perform_later(chat, chat.latest_user_message_id)
  end

  def update_memorize(data)
    chat.update!(memorize: ActiveModel::Type::Boolean.new.cast(data["memorize"]))
    ChatChannel.broadcast_to(chat, type: "memorize_updated", memorize: chat.memorize)
  end

  private

  def chat
    @chat ||= Chat.find(params[:chat_id])
  end
end
