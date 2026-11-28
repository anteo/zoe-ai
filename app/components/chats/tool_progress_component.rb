module Chats
  class ToolProgressComponent < ApplicationComponent
    attr_reader :icon, :text, :typography_class

    def initialize(chat:, text:, icon: nil, typography_class: "text-xs")
      @icon = icon
      @text = text
      @typography_class = typography_class
    end
  end
end
