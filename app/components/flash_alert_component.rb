# frozen_string_literal: true

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
    ENV.fetch("ACTION_FLASH_TIMEOUT_MS", "5000").to_i.clamp(0, 600_000)
  end
end
