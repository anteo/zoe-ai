require "ruby_llm/mcp"

load Rails.root.join("config/mcp.rb")

RubyLLM::MCP.configure do |config|
  config.logger = Rails.logger
  config.log_level = Rails.env.production? ? Logger::WARN : Logger::INFO
  config.roots = [Rails.root]
end

Rails.application.config.to_prepare do
  AI.reset_mcp_clients!
end
