class AdminConsoleChannel < ApplicationCable::Channel
  SNAPSHOT_MAX_BYTES = 48_000
  STREAM = "admin_console".freeze

  def subscribed
    return reject unless current_user&.admin?

    stream_from STREAM, coder: ActiveSupport::JSON do |payload|
      handle_stream_payload(payload)
    end

    transmit(snapshot_payload)
  end

  private

  def snapshot_payload
    snapshot = {
      type: "snapshot",
      level: selected_level,
      limit: SystemLog.console_limit,
      logs: []
    }
    logs = SystemLog.recent_for_level(selected_level).map(&:to_console_payload)

    logs.reverse_each do |log|
      candidate_logs = [ log, *snapshot[:logs] ]
      break if snapshot.merge(logs: candidate_logs).to_json.bytesize > SNAPSHOT_MAX_BYTES

      snapshot[:logs] = candidate_logs
    end

    snapshot
  end

  def handle_stream_payload(payload)
    return unless SystemLog.matches_level?(payload["severity"] || payload[:severity], selected_level)

    transmit({ type: "append", log: payload })
  end

  def selected_level
    @selected_level ||= SystemLog.normalize_level(params[:level])
  end
end
