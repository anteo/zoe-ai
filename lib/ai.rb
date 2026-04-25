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

  def paint(prompt, with: nil, model: nil,
            provider: nil,
            assume_model_exists: false,
            size: "1024x1024",
            context: nil)
    if with.present?
      config = context&.config || RubyLLM.config
      model ||= config.default_image_model
      model, provider_instance = RubyLLM::Models.resolve(model, provider: provider, assume_exists: assume_model_exists,
                                                config: config)
      model_id = model.id

      if provider_instance.is_a?(RubyLLM::Providers::OpenRouter)
        provider_instance.paint(prompt, model: model_id, size:, images: Array.wrap(with))
      else
        raise RubyLLM::Error, "Only OpenRouter provider is currently supported for image edits"
      end
    else
      RubyLLM::Image.paint(prompt, model:, provider:, assume_model_exists:, size:, context:)
    end
  end
end
