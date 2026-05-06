class ChatsController < ApplicationController
  before_action :find_chat, only: [ :show, :destroy ]
  before_action :find_history_chat, only: [ :history_detail ]
  before_action :find_default_chat, only: [ :show ]
  before_action :build_default_chat, only: [ :new, :show ]

  attr_reader :chat
  helper_method :chat

  def new
    render 'show'
  end

  def show
  end

  def destroy
    chat&.destroy
    redirect_to(root_path)
  end

  def history_detail
    render Chats::HistoryDetailComponent.new(history_chat: @history_chat, current_character:)
  end

  def history_list
    @history_chats = current_user.chats
                                 .where(character: current_character, partner: current_partner)
                                 .preload(:last_visible_message)
                                 .order(created_at: :desc)
  end

  private

  def find_chat
    return unless params[:id].present?
    @chat = current_user.chats.find_by(id: params[:id])
    redirect_to(root_path) unless @chat && @chat.partner == current_partner && !@chat.closed?
  end

  def find_history_chat
    @history_chat = current_user.chats
                                .where(character: current_character, partner: current_partner)
                                .find_by(id: params[:id])
    head(:not_found) unless @history_chat
  end
end
