module AgentRunsHelper
  def agent_run_event_text(event)
    case event.kind
    when "status"
      status = event.data["status"]
      t("agent_runs.status.#{status}") if status.in?(%w[queued running completed failed])
    when "tool_call", "tool_result"
      tool = event.data["tool"].to_s.truncate(80).presence
      state = event.kind
      state = "tool_failed" if state == "tool_result" && event.data["success"] == false
      tool ? t("agent_runs.events.#{state}_named", tool:) : t("agent_runs.events.#{state}")
    when "result", "error"
      key = event.data["source"] == "workspace" ? "workspace_#{event.kind}" : event.kind
      t("agent_runs.events.#{key}")
    end
  end
end
