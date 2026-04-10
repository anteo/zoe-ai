# frozen_string_literal: true

class MessagesController < ApplicationController
  before_action :find_chat
  before_action :build_default_chat

  attr_reader :chat

  def create
    content = RubyLLM::Content.new(message_params[:content], message_params[:attachments])

    if chat.new_record?
      chat.save
      chat.add_message(role: :user, content:)

      redirect_to chat_path(chat)
    else
      message = chat.add_message(role: :user, content:)

      stream = []
      stream << turbo_stream.append(
        "chat-messages",
        MessageComponent.new(message:, current_user:)
      )
      stream << turbo_stream.replace(
        "chat-input",
        ChatInputComponent.new(chat:, current_user:)
      )

      respond_to do |format|
        format.turbo_stream { render turbo_stream: stream }
        format.html { redirect_to chat_path(chat) }
      end
    end

    RespondJob.perform_later(chat)
  end

  def update
    message = find_message
    return head(:not_found) unless message
    return head(:forbidden) unless message.user?

    message.chat.messages.where("id > ?", message.id).destroy_all
    message.update!(content: params.require(:message).permit(:content)[:content])
    RespondJob.perform_later(message.chat)

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("chat-messages", ChatComponent.new(chat: message.chat, current_user:)) }
      format.html { redirect_to chat_path(message.chat) }
    end
  end

  def destroy
    message = find_message
    return head(:not_found) unless message

    message.chat.messages.where("id >= ?", message.id).destroy_all

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("chat-messages", ChatComponent.new(chat: message.chat, current_user:)) }
      format.html { redirect_to chat_path(message.chat) }
    end
  end

  def resend
    message = find_message
    return head(:not_found) unless message
    return head(:forbidden) unless message.user?

    message.chat.messages.where("id > ?", message.id).destroy_all
    RespondJob.perform_later(message.chat)

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("chat-messages", ChatComponent.new(chat: message.chat, current_user:)) }
      format.html { redirect_to chat_path(message.chat) }
    end
  end

  private

  def find_chat
    @chat = Chat.find_by(id: params[:chat_id], user: @current_user)
  end

  def find_message
    Message.joins(:chat).where(id: params[:id], chats: { user: @current_user }).first
  end

  def message_params
    params.require(:message).permit(:content, attachments: [])
  end
end
