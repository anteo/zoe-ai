module Chats
  class HistoryDrawerComponent < ApplicationComponent
    attr_reader :current_chat_id

    def initialize(current_chat_id: nil)
      @current_chat_id = current_chat_id
    end
  end
end
