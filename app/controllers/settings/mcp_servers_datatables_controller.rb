module Settings
  class MCPServersDatatablesController < ApplicationController
    before_action :require_admin!

    def show
      load_datatable(datatable_class: Settings::MCPServersDatatableComponent, scope: MCPServer.all)
      render turbo_frame_request_id == @datatable.results_frame_id ? @datatable.results_component : @datatable, layout: false
    end
  end
end
