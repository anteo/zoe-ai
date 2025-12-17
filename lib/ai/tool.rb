module AI
  class Tool < RubyLLM::Tool
    class Failure < RubyLLM::Error; end

    attr_reader :chat

    def initialize(chat)
      @chat = chat
    end

    def execute(...)
      super
    rescue Failure => e
      { error: e.message }
    end

    def fail!(error)
      raise Failure, error
    end
  end
end
