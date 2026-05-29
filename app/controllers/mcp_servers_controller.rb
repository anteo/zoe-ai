class MCPServersController < ApplicationController
  before_action :require_admin!
  before_action :find_mcp_server, only: [ :edit, :update, :start, :stop, :destroy ]

  def index
    render_datatable(Settings::MCPServersDatatableComponent)
  end

  def new
    @mcp_server = MCPServer.new(active: false, transport_type: "stdio")
    render_modal
  end

  def create
    @mcp_server = MCPServer.new(mcp_server_params.to_h)

    if @mcp_server.save
      @close_modal = true
      flash[:notice] = t(:text_successful_save, name: MCPServer.model_name.human)
      render
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    render_modal
  end

  def update
    if @mcp_server.update(mcp_server_params)
      @close_modal = true
      flash[:notice] = t(:text_successful_save, name: MCPServer.model_name.human)
      render
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def start
    if @mcp_server.update(active: true)
      render :action
    else
      flash[:alert] = @mcp_server.errors.full_messages.to_sentence
      render :action, status: :unprocessable_entity
    end
  end

  def stop
    if @mcp_server.update(active: false)
      render :action
    else
      flash[:alert] = @mcp_server.errors.full_messages.to_sentence
      render :action, status: :unprocessable_entity
    end
  end

  def destroy
    @mcp_server.enqueue_destroy_job!
  end

  private

  def find_mcp_server
    @mcp_server = MCPServer.find(params[:id])
  end

  def mcp_server_params
    allowed = [ :active, :config_json, :name, :transport_type ]
    allowed << :key if action_name == "create"
    params.require(:mcp_server).permit(*allowed)
  end
end
