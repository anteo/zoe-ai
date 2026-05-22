module AI
  class EmptyAssistantResponseError < RubyLLM::Error
    def initialize(message = I18n.t(:text_empty_response_from_model))
      super
    end
  end
end
