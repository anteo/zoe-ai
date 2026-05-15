module Settings
  class MCPServersDatatableComponent < Datatable::BaseComponent
    model MCPServer
    default_sort "name asc"
    path_helper :mcp_servers_path
  end
end
