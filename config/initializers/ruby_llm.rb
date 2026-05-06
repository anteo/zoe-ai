rubyllm_logger = RubyLLM.logger

Rails.application.config.to_prepare do
  system_logger = AI::SystemLogger.instance

  Setting.watch(:ai) do |_context|
    RubyLLM.configure do |config|
      cfg = Setting.ai
      providers = cfg.providers

      config.openai_api_key = providers.openai.api_key
      config.anthropic_api_key = providers.anthropic.api_key
      config.gemini_api_key = providers.gemini.api_key
      config.mistral_api_key = providers.mistral.api_key
      config.perplexity_api_key = providers.perplexity.api_key
      config.xai_api_key = providers.xai.api_key
      config.openrouter_api_key = providers.openrouter.api_key
      config.deepseek_api_key = providers.deepseek.api_key
      config.ollama_api_base = providers.ollama.api_base
      config.vertexai_project_id = providers.vertexai.project_id
      config.vertexai_location = providers.vertexai.location
      config.bedrock_api_key = providers.bedrock.api_key
      config.bedrock_secret_key = providers.bedrock.secret_key
      config.bedrock_region = providers.bedrock.region
      config.bedrock_session_token = providers.bedrock.session_token

      config.default_model = cfg.models.default_model
      config.default_embedding_model = cfg.models.default_embedding_model
      config.default_image_model = cfg.models.default_image_model
      config.request_timeout = cfg.request_timeout

      system_logger.level = cfg.debug? ? Logger::DEBUG : Logger::INFO
      rubyllm_logger.level = cfg.debug? ? Logger::DEBUG : Logger::INFO

      RubyLLM.instance_variable_set(:@logger, nil)
      config.logger = ActiveSupport::BroadcastLogger.new(rubyllm_logger, system_logger)
    end

    RubyLLM::Provider.register :openrouter, AI::Providers::OpenRouter
  end

  Setting.on_change(:"ai.providers") { RefreshModelsRegistryJob.perform_later }
end

RubyLLM.configure do |config|
  config.model_registry_file = Rails.root.join("config", "models.json")
  config.use_new_acts_as = true
end

RubyLLM.singleton_class.class_eval do
  def chat(...)
    AI::Chat.new(...)
  end
end
