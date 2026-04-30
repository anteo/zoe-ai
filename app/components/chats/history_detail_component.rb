# frozen_string_literal: true

class Chats::HistoryDetailComponent < ApplicationComponent
  attr_reader :history_chat, :current_character

  def initialize(history_chat:, current_character:)
    @history_chat = history_chat
    @current_character = current_character
  end
end
