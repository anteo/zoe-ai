class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include HttpAcceptLanguage::AutoLocale

  helper :view_components

  attr_reader :current_character

  before_action :set_current_character

  private

  def current_user
    # Current user is hard-coded for now
    @current_user ||= User.find_by(id: 3)
  end

  def set_current_character
    characters = current_user.characters
    @current_character = characters.find_by(id: session[:character_id]) ||
                         characters.order(:name).first
  end

  def find_default_chat
    @chat ||= current_user.chats.where(character: @current_character, partner: Character.ai, created_at: Date.current.all_day)
                          .order(created_at: :desc)
                          .first
  end

  def build_default_chat
    @chat ||= AI::Zoe.build_chat(character: @current_character, partner: Character.ai, user: current_user)
  end
end
