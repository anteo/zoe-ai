# frozen_string_literal: true

module AI
  module Providers
    # Ollama Cloud API integration.
    # Hosted OpenAI-compatible endpoints at https://ollama.com/v1.
    class OllamaCloud < RubyLLM::Providers::Ollama
      def api_base
        @config.ollama_cloud_api_base || "https://ollama.com/v1"
      end

      def headers
        { "Authorization" => "Bearer #{@config.ollama_cloud_api_key}" }
      end

      class << self
        def slug
          "ollama_cloud"
        end

        def configuration_options
          %i[ollama_cloud_api_base ollama_cloud_api_key]
        end

        def configuration_requirements
          %i[ollama_cloud_api_key]
        end

        def local?
          false
        end

        def assume_models_exist?
          true
        end

        def capabilities
          RubyLLM::Providers::Ollama::Capabilities
        end
      end
    end
  end
end
