module Chats
  class HistoryDrawerComponent < ApplicationComponent
    attr_reader :show_trigger

    def initialize(show_trigger: true)
      @show_trigger = show_trigger
    end
  end
end
