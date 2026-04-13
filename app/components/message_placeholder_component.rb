# frozen_string_literal: true

class MessagePlaceholderComponent < ApplicationComponent
  attr_reader :chat, :current_character

  def initialize(chat:, current_character:)
    @chat = chat
    @current_character = current_character
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
