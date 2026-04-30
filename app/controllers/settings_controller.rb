class SettingsController < ApplicationController
  before_action :require_admin!
  before_action :find_section_proxy, only: [ :update ]

  def show
    @section = params[:section]
    if turbo_frame_request_id == "settings-body"
      render :body
    end
  end

  def update
    @section = params[:section]

    if @section_proxy.update(**settings_params, context: { user: current_user })
      flash.now[:notice] = t(:text_settings_saved)
    end

    render :body
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
