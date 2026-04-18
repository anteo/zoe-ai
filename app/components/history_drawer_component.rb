# frozen_string_literal: true

class HistoryDrawerComponent < ApplicationComponent
  attr_reader :history_chats

  def initialize(history_chats:)
    @history_chats = history_chats
  end
end
