class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include Pagy::Method
  include HttpAcceptLanguage::AutoLocale
  include DatatableSupport

  extend ViewComponentsHelper

  append_view_path "#{Rails.root}/app/components"

  helper :view_components

  attr_reader :current_character, :current_partner

  before_action :redirect_to_setup_if_empty
  before_action :authenticate_user_without_root_alert!, unless: :devise_controller?
  before_action :set_current_character, unless: :devise_controller?
  before_action :set_current_partner, unless: :devise_controller?
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper_method :current_character, :current_partner
  helper_method :self_registration_open?, :turbo_referrer_frame_id

  private

  def authenticate_user_without_root_alert!
    return if user_signed_in?
    return authenticate_user! unless suppress_unauthenticated_root_alert?

    return if warden.authenticate(scope: :user)

    store_location_for(:user, request.fullpath) if request.get?
    redirect_to new_user_session_path
  end

  def default_chat
    @default_chat ||= current_user.chats
                                  .where(character: current_character, partner: current_partner,
                                         created_at: Date.current.all_day, closed: false)
                                  .order(created_at: :desc)
                                  .first
  end

  def set_current_character
    return unless user_signed_in?

    @current_character = current_user.main_character || current_user.characters.human.order(:name).first
  end

  def set_current_partner
    return unless user_signed_in?

    selected_id = session[:partner_id]
    @current_partner = current_user.characters.ai.find_by(id: selected_id) || Character.default_ai
  end

  def find_default_chat
    @chat ||= default_chat
  end

  def build_default_chat
    @chat ||= AI::Agents::Zoe.build_chat(character: current_character, partner: current_partner, user: current_user)
  end

  def redirect_to_setup_if_empty
    return if %w[/register /up].include?(request.path)
    redirect_to "/register" unless User.exists?
  end

  def self_registration_open?
    !User.exists? || Setting.app.self_registration
  end

  def suppress_unauthenticated_root_alert?
    request.get? && request.path == root_path
  end

  def require_admin!
    redirect_to root_path, alert: t(:text_access_denied) unless current_user&.admin?
  end

  def configure_permitted_parameters
    keys = %i[first_name last_name time_zone]
    devise_parameter_sanitizer.permit(:sign_up, keys:)
    devise_parameter_sanitizer.permit(:account_update, keys:)
  end

  def render_refresh
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.refresh(request_id: nil) }
      format.html { redirect_back fallback_location: root_path }
    end
  end

  def render_modal(**args)
    html = render_to_string(**args, formats: [ :html ])
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.show_modal(html) }
      format.html { redirect_to root_path }
    end
  end

  def turbo_referrer_frame_id
    request.headers["X-Turbo-Referrer-Frame-Id"]
  end
end
