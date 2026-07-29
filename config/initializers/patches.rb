require Rails.root.join("lib/patches").to_s

Patches.register %w[
  Faraday::Logging::Formatter
  MissionControl::Jobs::ApplicationController
  RubyLLM::Configuration
  RubyLLM::Context
  RubyLLM
  RubyLLM::MCP
  RubyLLM::MCP::Client
  RubyLLM::MCP::Native::Client
  RubyLLM::MCP::Native::Transport
  RubyLLM::MCP::Native::Transports::Stdio
  RubyLLM::Models
  RubyLLM::Provider
  RubyLLM::Providers::Gemini
  RubyLLM::Providers::Ollama
  RubyLLM::Providers::OpenAI
  RubyLLM::Providers::OpenRouter
  RubyLLM::Providers::OpenRouter::Models
  RubyLLM::Providers::DeepSeek
  RubyLLM::Providers::DeepSeek::Capabilities
  SimpleForm::Inputs::Base
  Turbo::Streams::TagBuilder
  Turbo::StreamsChannel
]

Rails.application.config.to_prepare do
  Patches.apply!
end
