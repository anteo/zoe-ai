# frozen_string_literal: true

class DialogsController < ApplicationController
  before_action :find_chat
  before_action :find_default_chat, only: [:show]
  before_action :build_default_chat, only: [:new, :show]

  def new
    render 'show'
  end

  def show
  end

  def destroy
  end

  private

  def chat_params
    params.require(:dialog).permit(:initiator_id, :companion_id)
  end

  def find_chat
    @dialog = Dialog.find_by(id: params[:id])
  end
end
