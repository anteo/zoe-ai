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

  def paint(...)
    RubyLLM::Image.paint(...)
  end
end
