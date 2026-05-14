module Settings
  class MCPServerRowComponent < ApplicationComponent
    attr_reader :mcp_server

    def initialize(mcp_server_row:, in_progress: false)
      @mcp_server = mcp_server_row
      @in_progress = in_progress
    end

    def in_progress?
      @in_progress
    end
  end
end
