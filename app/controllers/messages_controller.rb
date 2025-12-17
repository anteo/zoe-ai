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

  private

  def find_chat
    @chat = Chat.find_by(id: params[:chat_id], user: @current_user)
  end

  def message_params
    params.require(:message).permit(:content, attachments: [])
  end
end
