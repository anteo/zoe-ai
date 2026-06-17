module Chats
  class ChatInputComponent < ApplicationComponent
    attr_reader :chat, :current_character

    def initialize(chat:, current_character:)
      @chat = chat
      @current_character = current_character
    end

    def tts_available?
      AI.tts_enabled?
    end
  end
end
