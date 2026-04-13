# frozen_string_literal: true

class CharacterSelectorComponent < ApplicationComponent
  attr_reader :current_character

  def character_options
    @character_options ||= Character.joins(:user).order(:name)
  end

  def initialize(current_character:)
    @current_character = current_character
  end
end