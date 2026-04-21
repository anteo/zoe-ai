# frozen_string_literal: true

class MessagesController < ApplicationController
  before_action :find_message, only: [ :update, :destroy, :resend ]
  before_action :find_chat
  before_action :build_default_chat

  attr_reader :chat, :message
  helper_method :chat, :message

  def create
    content = RubyLLM::Content.new(message_params[:content], message_params[:attachments])
    memorize = message_params[:memorize] != "false"

    if chat.new_record?
      CloseChatJob.perform_later(default_chat) if default_chat

      chat.memorize = memorize
      chat.save!
      message = chat.add_message(role: :user, content:)
      message.update_column(:memorize, chat.memorize)

      redirect_to chat_path(chat)
    else
      chat.update_column(:memorize, memorize) if chat.memorize != memorize
      message = chat.add_message(role: :user, content:)
      message.update_column(:memorize, chat.memorize)

      stream = []
      stream << turbo_stream.append(
        "chat-messages",
        MessageComponent.new(message:, current_character:)
      )
      stream << turbo_stream.replace(
        "chat-input",
        ChatInputComponent.new(chat: chat, current_character:)
      )

      respond_to do |format|
        format.turbo_stream { render turbo_stream: stream }
        format.html { redirect_to chat_path(chat) }
      end
    end

    RespondJob.perform_later(chat)
  end

  def update
    return head(:forbidden) unless message.user?

    message.destroy_later_messages
    message.update!(content: message_params[:content],
                    facts_extracted: false)

    RespondJob.perform_later(chat)

    render_chat
  end

  def destroy
    message.destroy
    message.destroy_later_messages

    render_chat
  end

  def resend
    return head(:forbidden) unless message.user?

    message.destroy_later_messages
    RespondJob.perform_later(chat)

    render_chat
  end

  private

  def find_chat
    @chat ||= current_user.chats.find_by(id: params[:chat_id])
    head(:forbidden) if @chat && @chat.character != current_character
    head(:not_found) if @chat&.closed?
  end

  def render_chat
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("chat-messages", ChatComponent.new(chat:, current_character:)) }
      format.html { redirect_to chat_path(chat) }
    end
  end

  def find_message
    @message = Message.joins(:chat).where(id: params[:id], chats: { character: current_character, user: current_user }).first
    @chat = @message&.chat
    head(:not_found) unless @message
  end

  def message_params
    params.require(:message).permit(:content, :memorize, attachments: [])
  end
end
