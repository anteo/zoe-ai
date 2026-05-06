module Chats
  class MessageComponent < ApplicationComponent
    attr_reader :message, :current_character

    def initialize(message:, current_character:, read_only: false)
      @message = message
      @current_character = current_character
      @read_only = read_only
    end

    def sender
      message.character
    end

    def is_current_character?
      sender == current_character
    end

    def bubble_class
      is_current_character? ? "chat chat-end" : "chat chat-start"
    end

    def bubble_color
      is_current_character? ? "bg-primary text-primary-content" : "bg-base-300"
    end

    def image_attachments
      message.attachments.select(&:image?)
    end

    def file_attachments
      message.attachments.reject(&:image?)
    end

    def read_only?
      @read_only
    end
  end
end
