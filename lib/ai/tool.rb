module AI
  class Tool < RubyLLM::Tool
    class Failure < RubyLLM::Error; end

    attr_reader :chat

    def initialize(chat)
      @chat = chat
    end

    def current_character
      chat.character
    end

    def current_user
      chat.user
    end

    def execute(...)
      super
    rescue Failure => e
      { error: e.message }
    end

    def fail!(error)
      raise Failure, error
    end

    def params_schema
      # Reset @json_schema, so that it's recalculated each time
      definition = self.class.params_schema_definition
      definition&.instance_variable_set(:@json_schema, nil)
      super
    end

    def description
      desc = super
      if desc.is_a?(Proc)
        instance_exec(&desc)
      else
        desc
      end
    end
  end
end
