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

    if @section_proxy.update(**normalized_settings_params, context: { user: current_user })
      if params[:save]
        flash[:notice] = t(:text_settings_saved)
        return redirect_back(fallback_location: root_path, status: :see_other)
      else
        flash.now[:notice] = t(:text_settings_saved)
      end
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

  def normalized_settings_params
    permitted = raw_settings_params.to_h.symbolize_keys
    autocomplete_attributes.each_with_object(permitted.dup) do |source_key, acc|
      target_key = source_key.to_s.delete_suffix("_autocomplete").to_sym
      target_value = acc[target_key].to_s.strip
      source_value = acc[source_key].to_s.strip

      acc[target_key] = source_value if target_value.blank? && source_value.present?
      acc.delete(source_key)
    end
  end

  def raw_settings_params
    params.require(@section_proxy.class.model_name.param_key)
          .permit(*permitted_settings_attributes)
  end

  def permitted_settings_attributes
    attrs = @section_proxy.class.permitted_attributes.dup
    attrs + autocomplete_attributes
  end

  def autocomplete_attributes
    submitted_keys = settings_raw_input.keys.map(&:to_s)
    submitted_keys
      .grep(/_autocomplete\z/)
      .map(&:to_sym)
      .select do |key|
        base_key = key.to_s.delete_suffix("_autocomplete").to_sym
        @section_proxy.class.permitted_attributes.include?(base_key)
      end
  end

  def settings_raw_input
    params.fetch(@section_proxy.class.model_name.param_key, ActionController::Parameters.new)
  end

end
