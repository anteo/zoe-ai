require Rails.root.join("lib/patches").to_s

Patches.register %w[
  MissionControl::Jobs::ApplicationController
  RubyLLM::Providers::DeepSeek
  RubyLLM::Providers::DeepSeek::Capabilities
]

Rails.application.config.to_prepare do
  Patches.apply!
end
