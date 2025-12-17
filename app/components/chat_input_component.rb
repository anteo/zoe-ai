# frozen_string_literal: true

class ChatInputComponent < ApplicationComponent
  attr_reader :chat, :current_user

  def initialize(chat:, current_user:)
    @chat = chat
    @current_user = current_user
  end
end
