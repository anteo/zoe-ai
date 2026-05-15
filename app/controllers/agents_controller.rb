class AgentsController < ApplicationController
  before_action :require_admin!
  before_action :find_agent, only: [ :edit, :update, :destroy ]

  def index
    load_datatable(datatable_class: Settings::AgentsDatatableComponent, scope: Agent.includes(:model, :mcp_servers))
    render turbo_frame_request_id == @datatable.results_frame_id ? @datatable.results_component : @datatable, layout: false
  end

  def new
    @agent = Agent.new(active: true)
    render_modal
  end

  def create
    @agent = Agent.new(agent_params)

    if @agent.save
      @close_modal = true
      flash[:notice] = t(:text_successful_save, name: Agent.model_name.human)
      render
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    render_modal
  end

  def update
    if @agent.update(agent_params)
      @close_modal = true
      flash[:notice] = t(:text_successful_save, name: Agent.model_name.human)
      render
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @agent.destroy
      flash[:notice] = t(:text_successful_delete, name: Agent.model_name.human)
    else
      flash[:alert] = @agent.errors.full_messages.to_sentence
    end

    render
  end

  private

  def find_agent
    @agent = Agent.find(params[:id])
  end

  def agent_params
    allowed = [
      :instructions,
      :model_id,
      :name,
      :temperature,
      :thinking_budget,
      :thinking_effort,
      mcp_server_ids: []
    ]

    allowed.unshift(:active) unless @agent&.builtin?

    params.require(:agent).permit(*allowed)
  end
end
