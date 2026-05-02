module AI
  class ModelNotConfiguredError < RubyLLM::Error
    def initialize(message = I18n.t(:text_model_not_configured))
      super
    end
  end
end
