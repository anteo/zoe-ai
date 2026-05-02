module AI
  class Chat < RubyLLM::Chat
    def instructions
      @messages.detect { it.role == :system }&.content
    end

    def complete(...)
      super
    rescue RubyLLM::ModelNotFoundError => e
      raise e unless e.message.to_s.match?(/\AUnknown model:\s*\z/)

      raise AI::ModelNotConfiguredError
    end
  end
end
