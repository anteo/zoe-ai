require Rails.root.join("lib/patches").to_s

Patches.register %w[
  MissionControl::Jobs::ApplicationController
  RubyLLM::MCP
  RubyLLM::MCP::Client
  RubyLLM::MCP::Native::Client
  RubyLLM::MCP::Native::Transport
  RubyLLM::MCP::Native::Transports::Stdio
  RubyLLM::Providers::DeepSeek
  RubyLLM::Providers::DeepSeek::Capabilities
  Turbo::Streams::TagBuilder
  Turbo::StreamsChannel
]

Rails.application.config.to_prepare do
  Patches.apply!
end
