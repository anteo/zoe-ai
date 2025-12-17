# frozen_string_literal: true

class ChatComponent < ApplicationComponent
  attr_reader :chat, :current_user

  def initialize(chat:, current_user:)
    @chat = chat
    @current_user = current_user
  end

  def messages
    @chat.messages_association.visible.order(:created_at)
  end

  def new?
    @chat.new_record?
  end
end
