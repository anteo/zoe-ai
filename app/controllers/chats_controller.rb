# frozen_string_literal: true

class ChatsController < ApplicationController
  before_action :find_chat
  before_action :find_default_chat, only: [:show]
  before_action :build_default_chat, only: [:new, :show]

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

  private

  def find_chat
    @chat = current_user.chats.find_by(id: params[:id])
    redirect_to(root_path) if @chat && @chat.character != current_character
    redirect_to(root_path) if @chat&.from_previous_day?
  end
end
