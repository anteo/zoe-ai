module UI
  class FlashAlertComponent < ApplicationComponent
    attr_reader :type, :message, :details

    def initialize(type:, message:, details: [])
      @type = type.to_s
      @message = message
      @details = Array(details).compact_blank
    end

    def alert_class
      type == "alert" ? "alert-error" : "alert-success"
    end

    def show_details?
      details.any?
    end

    def timeout_ms
      return 0 if type == "alert"

      Setting.ui.flash_timeout_ms.clamp(0, 600_000)
    end
  end
end
