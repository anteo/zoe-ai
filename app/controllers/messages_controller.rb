class MessagesController < ApplicationController
  before_action :find_message, only: [ :update, :destroy, :resend ]
  before_action :find_chat
  before_action :build_default_chat

  attr_reader :chat, :message
  helper_method :chat, :message

  def create
    content = RubyLLM::Content.new(message_params[:content], message_params[:attachments])
    memorize = message_params[:memorize] != "false"
    tts_enabled = message_params[:tts_enabled] != "false"
    respond_delay = nil

    if chat.new_record?
      CloseChatJob.perform_later(default_chat) if default_chat

      chat.memorize = memorize
      chat.save!
      chat.deliver_pending_messages!
      message = chat.add_message(role: :user, content:)
      message.update_columns(memorize: chat.memorize, tts_enabled:)
      respond_delay = 0.5.seconds

      redirect_to chat_path(chat)
    else
      chat.update_column(:memorize, memorize) if chat.memorize != memorize
      message = chat.add_message(role: :user, content:)
      message.update_columns(memorize: chat.memorize, tts_enabled:)

      stream = []
      stream << turbo_stream.before(
        "message-placeholder-slot-#{chat.id}",
        Chats::MessageComponent.new(message:, current_character:)
      )
      stream << turbo_stream.replace(
        "chat-input",
        Chats::ChatInputComponent.new(chat: chat, current_character:)
      )

      respond_to do |format|
        format.turbo_stream { render turbo_stream: stream }
        format.html { redirect_to chat_path(chat) }
      end
    end

    RespondJob.set(wait: respond_delay).perform_later(chat, message.id)
  end

  def update
    return head(:forbidden) unless message.user?

    message.destroy_later_messages
    message.update!(content: message_params[:content],
                    tts_enabled: message_params[:tts_enabled] != "false",
                    facts_extracted: false)

    RespondJob.perform_later(chat, message.id)

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
    message.update_column(:tts_enabled, message_params[:tts_enabled] != "false") if message_params.key?(:tts_enabled)
    RespondJob.perform_later(chat, message.id)

    render_chat
  end

  private

  def find_chat
    return unless params[:chat_id].present?

    @chat ||= current_user.chats.dreaming(false).find_by(id: params[:chat_id])
    head(:not_found) unless @chat
    head(:forbidden) if @chat && @chat.character != current_character
    head(:not_found) if @chat&.closed?
  end

  def render_chat
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("chat-messages", Chats::ChatComponent.new(chat:)) }
      format.html { redirect_to chat_path(chat) }
    end
  end

  def find_message
    @message = Message.joins(:chat).where(id: params[:id], chats: { character: current_character, user: current_user, dream: false }).first
    @chat = @message&.chat
    head(:not_found) unless @message
  end

  def message_params
    params.require(:message).permit(:content, :memorize, :tts_enabled, attachments: [])
  end
end
