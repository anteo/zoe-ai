class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include HttpAcceptLanguage::AutoLocale

  helper :view_components

  attr_reader :current_character, :current_partner

  before_action :redirect_to_setup_if_empty
  before_action :authenticate_user!, unless: :devise_controller?
  before_action :set_current_character, unless: :devise_controller?
  before_action :set_current_partner, unless: :devise_controller?
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper_method :current_character, :current_partner

  private

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

    selected_id = session[:ai_character_id] || session[:character_id]
    @current_partner = current_user.characters.ai.find_by(id: selected_id) || Character.default_ai
  end

  def find_default_chat
    @chat ||= default_chat
  end

  def build_default_chat
    @chat ||= AI::Agents::Zoe.build_chat(character: current_character, partner: current_partner, user: current_user)
  end

  def redirect_to_setup_if_empty
    return if [ new_user_registration_path, user_registration_path, "/up" ].include?(request.path)
    redirect_to new_user_registration_path unless User.exists?
  end

  def require_admin!
    redirect_to root_path, alert: t(:text_access_denied) unless current_user&.admin?
  end

  def configure_permitted_parameters
    keys = %i[first_name last_name]
    devise_parameter_sanitizer.permit(:sign_up, keys:)
    devise_parameter_sanitizer.permit(:account_update, keys:)
  end

end
