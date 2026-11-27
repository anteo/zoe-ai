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
        Chats::ChatInputComponent.new(
          chat: chat,
          current_character:,
          transcription_mode: params[:transcription_mode],
          tts_enabled: message_params[:tts_enabled]
        )
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

    changed = change_chat_from_message(respond: true) do
      message.update!(content: message_params[:content],
                      tts_enabled: message_params[:tts_enabled] != "false",
                      facts_extracted: false)
    end
    return render_agent_running unless changed

    render_chat
  end

  def destroy
    return render_agent_running unless change_chat_from_message { message.destroy! }

    render_chat
  end

  def resend
    return head(:forbidden) unless message.user?

    changed = change_chat_from_message(respond: true) do
      message.update_column(:tts_enabled, message_params[:tts_enabled] != "false") if message_params.key?(:tts_enabled)
    end
    return render_agent_running unless changed

    render_chat
  end

  private

  def change_chat_from_message(respond: false)
    chat.with_lock do
      chat.agent_runs.reconcile_interrupted!
      next false if chat.agent_runs.running.exists?

      RespondJob.cancel(chat)
      TypeSentenceJob.cancel(chat)
      SpeakMessageJob.cancel(chat)
      chat.agent_runs.shown_in_chat.where(trigger_message_id: message.id..).update_all(hidden_from_chat: true)
      message.destroy_later_messages
      yield
      RespondJob.perform_later(chat, message.id) if respond
      true
    end
  end

  def render_agent_running
    alert = t("agent_runs.text_wait_before_changing_chat")
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = alert
        render turbo_stream: helpers.turbo_stream_flash_alerts
      end
      format.html { redirect_to chat_path(chat), alert:, status: :see_other }
    end
  end

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
