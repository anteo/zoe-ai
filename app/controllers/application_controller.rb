class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include HttpAcceptLanguage::AutoLocale

  helper :view_components

  attr_reader :current_character

  before_action :authenticate_user!, unless: :devise_controller?
  before_action :set_current_character, unless: :devise_controller?
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper_method :current_character

  private

  def default_chat
    @default_chat ||= current_user.chats
                                  .where(character: @current_character, partner: Character.ai,
                                         created_at: Date.current.all_day, closed: false)
                                  .order(created_at: :desc)
                                  .first
  end

  def set_current_character
    return unless user_signed_in?

    characters = current_user.characters
    @current_character = characters.find_by(id: session[:character_id]) ||
                         current_user.main_character ||
                         characters.order(:name).first
  end

  def find_default_chat
    @chat ||= default_chat
  end

  def build_default_chat
    @chat ||= AI::Zoe.build_chat(character: @current_character, partner: Character.ai, user: current_user)
  end

  def configure_permitted_parameters
    keys = %i[first_name last_name]
    devise_parameter_sanitizer.permit(:sign_up, keys:)
    devise_parameter_sanitizer.permit(:account_update, keys:)
  end
end
