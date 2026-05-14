module Settings
  class MCPServersDatatableComponent < Datatable::BaseComponent
    model MCPServer
    default_sort "name asc, key asc"
    path_helper :settings_mcp_servers_datatable_path
  end
end
