class SettingsController < ApplicationController
  before_action :require_admin!
  before_action :find_section_proxy, only: [ :update ]

  def show
    render layout: false if turbo_frame_request?
  end

  def section
    @section = params[:section]
    render layout: false
  end

  def update
    if @section_proxy.update(**settings_params, context: { user: current_user })
      @section = params[:section]
      flash.now[:notice] = t(:text_settings_saved)
      render :section, layout: false
    else
      @section = params[:section]
      render :section, layout: false, status: :unprocessable_entity
    end
  end

  private

  def find_section_proxy
    @section_proxy = (params[:scope] || params[:section]).to_s
                                                         .split(".")
                                                         .reduce(Setting, :public_send)
  rescue NoMethodError
    head :not_found
  end

  def settings_params
    params.require(@section_proxy.class.model_name.param_key)
          .permit(*@section_proxy.class.permitted_attributes)
  end
end
