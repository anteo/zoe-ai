# frozen_string_literal: true

class ChatsController < ApplicationController
  before_action :find_chat, only: [:show, :destroy]
  before_action :find_history_chat, only: [:history_detail]
  before_action :find_default_chat, only: [:show]
  before_action :build_default_chat, only: [:new, :show]
  before_action :load_history_chats, only: [:new, :show]

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
    render HistoryChatDetailComponent.new(history_chat: @history_chat, current_character:)
  end

  private

  def find_chat
    @chat = current_user.chats.find_by(id: params[:id])
    redirect_to(root_path) if @chat && @chat.character != current_character
    redirect_to(root_path) if @chat&.closed?
  end

  def find_history_chat
    @history_chat = current_user.chats
                                .where(character: current_character, partner: Character.ai)
                                .find_by(id: params[:id])
    head(:not_found) unless @history_chat
  end

  def load_history_chats
    @history_chats = current_user.chats
                                 .where(character: current_character, partner: Character.ai)
                                 .order(created_at: :desc)
  end
end
