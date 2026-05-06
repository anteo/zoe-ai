module Chats
  class ChatInputComponent < ApplicationComponent
    attr_reader :chat, :current_character

    def initialize(chat:, current_character:)
      @chat = chat
      @current_character = current_character
    end
  end
end
