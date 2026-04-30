# frozen_string_literal: true

class Chat::ChatComponent < ApplicationComponent
  attr_reader :chat, :dom_id

  def initialize(chat:, current_character:, read_only: false, stream: true, dom_id: "chat-messages")
    @chat = chat
    @stream = stream
    @dom_id = dom_id
  end

  def messages
    @chat.messages_association.visible.order(:created_at).flat_map do |message|
      display_messages(message)
    end
  end

  def new?
    @chat.new_record?
  end

  def read_only?
    @read_only
  end

  def stream?
    @stream
  end

  def current_character
    @chat.character
  end

  def current_partner
    @chat.partner
  end

  private

  def display_messages(message)
    return [ message ] unless message.assistant? && message.content.present?

    chunks = AI::SentenceSplitter.new(message.content).chunks
    return [ message ] if chunks.size <= 1

    chunks.each_with_index.map do |chunk, index|
      if index.zero?
        message.tap { |display_message| display_message.content = chunk.to_s }
      else
        message.dup.tap do |extra_message|
          extra_message.created_at = message.created_at
          extra_message.content = chunk.to_s
        end
      end
    end
  end
end
