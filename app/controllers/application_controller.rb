class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include HttpAcceptLanguage::AutoLocale

  helper :view_components

  attr_reader :current_character

  before_action :set_current_user

  private

  def set_current_user
    @current_character = User.find_by(id: session[:user_id])&.character ||
                    User.joins(:character).first&.character
  end

  def find_default_chat
    @chat ||= Chat.where(character: @current_character, partner: Character.ai, created_at: Date.current.all_day)
                  .order(created_at: :desc)
                  .first
  end

  def build_default_chat
    @chat ||= Chat.new(character: @current_character, partner: Character.ai)
  end
end
