# frozen_string_literal: true

class MessagePlaceholderComponent < ApplicationComponent
  attr_reader :chat, :current_user

  def initialize(chat:, current_user:)
    @chat = chat
    @current_user = current_user
  end

  private

  def bubble_class
    "chat chat-start"
  end

  def bubble_color
    "bg-base-300"
  end

  def sender
    chat.partner
  end
end
