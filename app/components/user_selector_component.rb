# frozen_string_literal: true

class UserSelectorComponent < ApplicationComponent
  attr_reader :current_character

  def user_options
    @user_options ||= User.joins(:character).includes(:character).order("characters.name")
  end

  def initialize(current_character:)
    @current_character = current_character
  end
end