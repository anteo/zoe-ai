module UI
  class ErrorComponent < ApplicationComponent
    attr_reader :chat, :current_character, :error

    def initialize(chat:, current_character:, error:)
      @chat = chat
      @current_character = current_character
      @error = error
    end

    private

    def bubble_class
      "chat chat-start"
    end

    def bubble_color
      "chat-bubble-error"
    end

    def sender
      chat.partner
    end
  end
end
