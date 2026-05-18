module AI
  class ModelNotConfiguredError < RubyLLM::Error
    def initialize
      @original_cause = $!
      msg = I18n.t(:text_model_not_configured)
      msg += " (#{@original_cause.message})" if @original_cause
      super(msg)
    end
  end
end
