module Chats
  class MessageComponent < ApplicationComponent
    attr_reader :message, :current_character

    def initialize(message:, current_character:, read_only: false)
      @message = message
      @current_character = current_character
      @read_only = read_only
    end

    def sender
      return message.partner if message.is_a?(PendingMessage)

      message.author
    end

    def is_current_character?
      sender == current_character
    end

    def bubble_class
      is_current_character? ? "chat chat-end" : "chat chat-start"
    end

    def bubble_color
      return "chat-bubble-error" if message.error?
      return "bg-base-100 text-base-content chat-bubble-postponed" if postponed_message?

      is_current_character? ? "bg-primary text-primary-content" : "bg-base-300"
    end

    def postponed_message?
      message.postponed?
    end

    def editable_message?
      message.persisted? && is_current_character? && !read_only? && !postponed_message?
    end

    def deletable_message?
      message.persisted? && !read_only? && !postponed_message?
    end

    def image_attachments
      message.attachments.select(&:image?)
    end

    def file_attachments
      message.attachments.reject(&:image?)
    end

    def read_only?
      @read_only || !message.is_a?(Message)
    end
  end
end
