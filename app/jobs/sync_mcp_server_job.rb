class SyncMCPServerJob < ApplicationJob
  limits_concurrency to: 1,
                     key: ->(mcp_server, **) { "sync_mcp_server:#{mcp_server.id}" },
                     on_conflict: :discard

  def perform(mcp_server, rebuild: false)
    mcp_server.sync_client!(rebuild:)
  end
end
