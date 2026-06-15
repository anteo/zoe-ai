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

    def call(args)
      normalized_args = normalize_args(args)
      payload = progress_payload(**normalized_args)
      broadcast_progress(payload) if payload.present?

      super
    ensure
      clear_progress if payload.present?
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

    def progress_payload(**)
      nil
    end

    private

    def broadcast_progress(payload)
      content = payload.is_a?(Hash) ? payload[:text].to_s : payload.to_s
      icon = payload.is_a?(Hash) ? payload[:icon].to_s.presence : nil
      return if content.blank?

      Turbo::StreamsChannel.broadcast_update_to(
        chat,
        target: "tool-progress-slot-#{chat.id}",
        content: Chats::ToolProgressComponent.new(chat:, text: content, icon:),
      )
    end

    def clear_progress
      Turbo::StreamsChannel.broadcast_update_to(
        chat,
        target: "tool-progress-slot-#{chat.id}",
        content: "",
      )
    end
  end
end
