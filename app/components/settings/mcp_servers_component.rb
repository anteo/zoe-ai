module Settings
  class MCPServersComponent < SectionComponent
    def mcp_servers
      @mcp_servers ||= MCPServer.order(:name, :key)
    end
  end
end
