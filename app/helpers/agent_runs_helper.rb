module AgentRunsHelper
  def agent_run_tool_call_groups(run)
    calls = []
    run.progress_events.each do |event|
      next unless agent_run_tool_event?(run, event)

      if event.kind == "tool_call"
        calls << { event:, result: nil }
      else
        keys = event.data["tool_call_id"].present? ? %w[source tool_call_id] : %w[source tool]
        call = calls.reverse_each.find do |entry|
          entry[:result].nil? && entry[:event].data.values_at(*keys) == event.data.values_at(*keys)
        end
        if call
          call[:result] = event
        elsif event.data["success"] == false
          calls << { event:, result: event }
        end
      end
    end
    calls.chunk_while do |previous, current|
      previous_event = previous.fetch(:event)
      current_event = current.fetch(:event)
      previous_event.data.values_at("source", "tool") == current_event.data.values_at("source", "tool") &&
        [previous, current].all? do |entry|
          entry[:result]&.data&.fetch("success", nil) == true && !entry.fetch(:event).data.key?("arguments")
        end
    end.to_a
  end

  def agent_run_latest_activity(run)
    event = run.progress_events.reverse_each.find do |entry|
      entry.kind == "status" || agent_run_tool_event?(run, entry)
    end
    return unless event

    tool = event.data["tool"].to_s.truncate(80)
    return if tool.blank?

    key = if event.kind == "tool_call"
      "tool_call_named"
    elsif event.data["success"] == false
      "tool_failed_named"
    else
      "last_tool_named"
    end
    t("agent_runs.events.#{key}", tool:)
  end

  def agent_run_argument_text(value)
    (value.is_a?(String) ? value : value.to_json).truncate(4_097)
  end

  private

  def agent_run_tool_event?(run, event)
    event.kind.in?(%w[tool_call tool_result]) &&
      event.data["tool_call_id"] != "workspace-#{run.id}"
  end
end
