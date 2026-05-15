class SettingsController < ApplicationController
  before_action :require_admin!
  before_action :find_section_proxy, only: [ :update ]

  def show
    @section = params[:section]
    if turbo_frame_request_id == "settings-body"
      render :body
    else
      render_modal
    end
  end

  def update
    @section = params[:section]
    settings_attributes = normalized_settings_params
    global_instruction_attributes = extract_global_instruction_attributes!(settings_attributes)

    if @section_proxy.update(**settings_attributes, context: { user: current_user }) &&
       update_global_instructions(global_instruction_attributes)
      return handle_test_smtp if params[:test_smtp]

      if params[:save]
        flash[:notice] = t(:text_settings_saved)
        return close_modal
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
    normalized = autocomplete_attributes.each_with_object(permitted.dup) do |source_key, acc|
      target_key = source_key.to_s.delete_suffix("_autocomplete").to_sym
      target_value = acc[target_key].to_s.strip
      source_value = acc[source_key].to_s.strip

      acc[target_key] = source_value if target_value.blank? && source_value.present?
      acc.delete(source_key)
    end

    preserve_sensitive_values(normalized)
  end

  def raw_settings_params
    params.require(@section_proxy.class.model_name.param_key)
          .permit(*permitted_settings_attributes)
  end

  def permitted_settings_attributes
    attrs = @section_proxy.class.permitted_attributes.dup
    attrs << { instructions_attributes: [ :id, :content, :_destroy ] } if instructions_section?
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

  def preserve_sensitive_values(attributes)
    smtp_attributes = attributes[:smtp_attributes]
    return attributes unless smtp_attributes.is_a?(Hash)
    return attributes unless smtp_attributes["password"].to_s.empty?

    smtp_attributes.delete("password")
    attributes
  end

  def extract_global_instruction_attributes!(attributes)
    return [] unless instructions_section?

    raw_items = attributes.delete(:instructions_attributes)
    return [] unless raw_items.respond_to?(:values)

    raw_items.values
  end

  def update_global_instructions(items)
    return true unless instructions_section?

    Instruction.transaction do
      items.each do |item|
        id = item[:id].presence || item["id"].presence
        content = item[:content].presence || item["content"].presence
        destroy = ActiveModel::Type::Boolean.new.cast(item[:_destroy] || item["_destroy"])

        instruction = id.present? ? Instruction.global.find_by(id:) : Instruction.new
        next if instruction.nil?

        if destroy || content.blank?
          instruction.destroy! if instruction.persisted?
          next
        end

        instruction.update!(character: nil, active: true, content:)
      end
    end

    true
  rescue ActiveRecord::ActiveRecordError
    false
  end

  def instructions_section?
    @section == "ai_instructions"
  end

  def handle_test_smtp
    SmtpTestMailer.test_email(recipient: current_user.email).deliver_now!
    flash.now[:notice] = t(:text_settings_smtp_test_sent, email: current_user.email)
    render :body
  rescue StandardError => e
    flash.now[:alert] = t(:text_settings_smtp_test_failed, error: e.message)
    render :body, status: :unprocessable_content
  end

end
