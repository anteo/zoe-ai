# frozen_string_literal: true

class ChatsController < ApplicationController
  before_action :find_chat
  before_action :find_default_chat, only: [:show]
  before_action :build_default_chat, only: [:new, :show]

  def new
    render 'show'
  end

  def show
  end

  def destroy
    @chat&.destroy
    redirect_to root_path
  end

  private

  def find_chat
    @chat = Chat.find_by(id: params[:id], user: @current_user)
  end
end
