require "ruby_llm/mcp"

RubyLLM::MCP.configure do |config|
  config.request_timeout = 30_000.to_i
  config.launch_control = :manual
  config.logger = Rails.logger
  config.log_level = Rails.env.production? ? Logger::WARN : Logger::INFO
  config.roots = [ Rails.root ]
end

Rails.application.config.to_prepare do
  AI.reset_mcp_clients!
end
