class ChatChannel < ApplicationCable::Channel
  def subscribed
    chat = Chat.find(params[:chat_id])
    stream_for chat
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def user_typing
    chat = Chat.find(params[:chat_id])
    StopTypingJob.perform_later(chat)
  end
end
