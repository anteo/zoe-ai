module AI
  module_function

  def mcp_server_configs
    [
      MCPClient.stdio_config(
        name: "Google Custom Search",
        command: "uvx mcp-google-cse",
        env: {
          "API_KEY" => "AIzaSyDG6QE4MNZ7GpHSOhgV292Y3TQ_GJYdeoQ",
          "ENGINE_ID" => "957e963ac8dee458d"
        }
      ),
      MCPClient.stdio_config(
        name: "Fetch",
        command: "uvx mcp-server-fetch",
      )
    ]
  end

  def mcp_client
    @mcp_client ||= MCPClient.create_client(mcp_server_configs:)
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
