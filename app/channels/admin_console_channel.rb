class AdminConsoleChannel < ApplicationCable::Channel
  STREAM = "admin_console".freeze

  def subscribed
    return reject unless current_user&.admin?

    stream_from STREAM, coder: ActiveSupport::JSON do |payload|
      handle_stream_payload(payload)
    end

    transmit({
      type: "snapshot",
      level: selected_level,
      limit: SystemLog.console_limit,
      logs: SystemLog.recent_for_level(selected_level).map(&:to_console_payload)
    })
  end

  private

  def handle_stream_payload(payload)
    return unless SystemLog.matches_level?(payload["severity"] || payload[:severity], selected_level)

    transmit({ type: "append", log: payload })
  end

  def selected_level
    @selected_level ||= SystemLog.normalize_level(params[:level])
  end
end
