module AI
  class Chat < RubyLLM::Chat
    def instructions
      @messages.detect { it.role == :system }&.content
    end
  end
end
