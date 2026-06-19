require_relative "ai/version"

module AI
  module_function

  def mcp_clients
    clients = RubyLLM::MCP.clients
    clients.respond_to?(:values) ? clients.values : Array.wrap(clients)
  end

  def mcp_tools
    mcp_clients.flat_map(&:tools).uniq(&:name)
  rescue StandardError => e
    Rails.logger.error("[MCP] failed to load tools: #{e.class}: #{e.message}")
    []
  end

  def wrap_mcp_tools(chat, tools)
    Array.wrap(tools).map { |tool| AI::Tools::MCPProxy.new(chat, tool) }
  end

  def reset_mcp_clients!
    return unless RubyLLM::MCP.instance_variable_defined?(:@clients)

    RubyLLM::MCP.close_connection
    RubyLLM::MCP.remove_instance_variable(:@clients)
  end

  def chat(...)
    AI::Chat.new(...)
  end

  def embed(...)
    RubyLLM::Embedding.embed(...)
  end

  def speak(...)
    AI::Speech.speak(...)
  end

  def tts_enabled?
    Setting.ai.models.default_tts_model.present? &&
      Setting.ai.voice.voice.present?
  end

  def tts_allowed_styles
    Setting.ai.voice.allowed_styles.to_s.split(",").map { it.strip.downcase }.reject(&:blank?)
  end

  def tts_style_examples
    tts_allowed_styles.map { "[[#{it}]]" }
  end

  def transcription_enabled?
    Setting.ai.models.default_transcription_model.present?
  end

  def paint(prompt, with: nil, mask: nil, params: {}, model: nil,
            provider: nil,
            assume_model_exists: false,
            size: "1024x1024",
            context: nil)
    if with.present? || mask.present?
      config = context&.config || RubyLLM.config
      model ||= config.default_image_model
      model, provider_instance = RubyLLM::Models.resolve(model, provider: provider, assume_exists: assume_model_exists,
                                                config: config)
      model_id = model.id

      if provider_instance.is_a?(RubyLLM::Providers::OpenRouter)
        provider_instance.paint(prompt, model: model_id, size:, with: Array.wrap(with), mask:, params:)
      else
        raise RubyLLM::Error, "Only OpenRouter provider is currently supported for image edits"
      end
    else
      RubyLLM::Image.paint(prompt, model:, provider:, assume_model_exists:, size:, context:, params:)
    end
  end

  def console
    SystemLogger.instance
  end
end
