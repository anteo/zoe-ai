class DestroyMCPServerJob < ApplicationJob
  limits_concurrency to: 1,
                     key: ->(mcp_server) { "destroy_mcp_server:#{mcp_server.id}" },
                     on_conflict: :discard

  def perform(mcp_server)
    mcp_server.destroy_with_client_cleanup!
  end
end
