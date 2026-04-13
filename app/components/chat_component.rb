# frozen_string_literal: true

class ChatComponent < ApplicationComponent
  attr_reader :chat, :current_character

  def initialize(chat:, current_character:)
    @chat = chat
    @current_character = current_character
  end

  def messages
    @chat.messages_association.visible.order(:created_at)
  end

  def new?
    @chat.new_record?
  end
end
