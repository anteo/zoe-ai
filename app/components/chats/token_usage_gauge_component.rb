module Chats
  class TokenUsageGaugeComponent < ApplicationComponent
    attr_reader :chat

    def initialize(chat:)
      @chat = chat
    end

    def enabled?
      chat.token_usage_context_window
      true
    rescue RubyLLM::Error
      false
    end

    def percentage
      chat.token_usage_percentage
    end

    def total_tokens
      chat.token_usage_total
    end

    def context_window
      chat.token_usage_context_window
    end

    def formatted_total_tokens
      format_tokens(total_tokens)
    end

    def formatted_context_window
      format_tokens(context_window)
    end

    def gauge_class
      return "text-error" if percentage >= 90
      return "text-warning" if percentage >= 70

      "text-default"
    end

    private

    def format_tokens(value)
      number = value.to_f
      return "0" if number <= 0

      units = %w[k m b]
      unit_index = -1

      while number >= 1024 && unit_index < units.length - 1
        number /= 1024.0
        unit_index += 1
      end

      return number.round.to_s if unit_index.negative?

      formatted = ("%.2f" % number).sub(/\.?0+$/, "")
      "#{formatted}#{units[unit_index]}"
    end
  end
end
