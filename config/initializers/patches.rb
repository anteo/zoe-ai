Patches.register %w[
  MissionControl::Jobs::ApplicationController
  RubyLLM::Providers::DeepSeek::Capabilities
  RubyLLM::Providers::DeepSeek::Chat
]

Rails.application.config.to_prepare do
  Patches.apply!
end
