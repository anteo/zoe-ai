RubyLLM.configure do |config|
  config.model_registry_file = Rails.root.join('config', 'models.json')

  config.openrouter_api_key = ENV['OPENROUTER_API_KEY']
  config.deepseek_api_key = ENV['DEEPSEEK_API_KEY']
  config.ollama_api_base = ENV['OLLAMA_API_BASE']

  config.default_model = ENV['DEFAULT_MODEL']
  config.default_embedding_model = ENV['DEFAULT_EMBEDDING_MODEL']
  config.default_image_model = ENV['DEFAULT_IMAGE_MODEL']

  config.use_new_acts_as = true
end

Rails.application.config.to_prepare do
  RubyLLM::Provider.register :openrouter, AI::Providers::OpenRouter
end

RubyLLM.singleton_class.class_eval do
  def chat(...)
    AI::Chat.new(...)
  end
end
