class Setting < ApplicationRecord
  include SettingConcern

  scope :app do
    setting :host, :string, default: "localhost"
    setting :port, :integer, default: 3000
    setting :protocol, :string, default: "http"
    setting :extra_hosts, :string, static: true # Rack host allowlist, boot-only
  end

  scope :ai do
    setting :default_model, :string
    setting :default_embedding_model, :string
    setting :default_image_model, :string
    setting :request_timeout, :integer, default: 30
    setting :debug, :boolean, default: false

    scope :providers do
      scope :openai do
        setting :api_key, :string
      end

      scope :anthropic do
        setting :api_key, :string
      end

      scope :gemini do
        setting :api_key, :string
      end

      scope :mistral do
        setting :api_key, :string
      end

      scope :perplexity do
        setting :api_key, :string
      end

      scope :xai do
        setting :api_key, :string
      end

      scope :openrouter do
        setting :api_key, :string
      end

      scope :deepseek do
        setting :api_key, :string
      end

      scope :ollama do
        setting :api_base, :string, default: "http://localhost:11434/v1"
        validates :api_base, url: true, allow_blank: true
      end

      scope :vertexai do
        setting :project_id, :string
        setting :location, :string
      end

      scope :bedrock do
        setting :api_key, :string
        setting :secret_key, :string
        setting :region, :string
        setting :session_token, :string
      end
    end
  end

  scope :google_client do
    setting :id, :string, static: true # OmniAuth middleware registered at boot
    setting :secret, :string, static: true
  end

  scope :mailer do
    setting :from, :string
    setting :reply_to, :string
    setting :perform_deliveries, :boolean, default: true
    setting :raise_delivery_errors, :boolean # nil → env-dependent default in initializer

    scope :smtp do
      setting :address, :string, default: "localhost"
      setting :port, :integer, default: 1025
      setting :domain, :string
      setting :username, :string
      setting :password, :string
      setting :authentication, :string
      setting :enable_starttls_auto, :boolean, default: true

      validates :port, numericality: { greater_than: 0, less_than: 65_536 }, allow_nil: true
    end
  end

  scope :ui do
    setting :max_message_bubbles, :integer, default: 3
    setting :flash_timeout_ms, :integer, default: 5000
  end

  scope :events do
    setting :maximum_count, :integer, default: 20
    setting :period_limit, :integer, default: 5
    setting :search_default_limit, :integer, default: 10
    setting :search_max_limit, :integer, default: 20
  end
end
