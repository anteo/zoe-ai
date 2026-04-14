# frozen_string_literal: true

class CharacterSelectorComponent < ApplicationComponent
  attr_reader :current_character, :current_user

  def character_options
    @character_options ||= current_user.characters.human.order(:name)
  end

  def initialize(current_character:, current_user:)
    @current_character = current_character
    @current_user = current_user
  end
end