module Chats
  class ToolProgressComponent < ApplicationComponent
    attr_reader :icon, :text

    def initialize(chat:, text:, icon: nil)
      @icon = icon
      @text = text
    end
  end
end
