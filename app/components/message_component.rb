# frozen_string_literal: true

class MessageComponent < ApplicationComponent
  attr_reader :message, :current_user

  def initialize(message:, current_user:)
    @message = message
    @current_user = current_user
  end

  def sender
    message.character
  end

  def is_current_user?
    sender == current_user
  end

  def bubble_class
    is_current_user? ? "chat chat-end" : "chat chat-start"
  end

  def bubble_color
    is_current_user? ? "bg-primary text-primary-content" : "bg-base-300"
  end

  def image_attachments
    message.attachments.select(&:image?)
  end

  def file_attachments
    message.attachments.reject(&:image?)
  end
end
