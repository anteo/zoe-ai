# frozen_string_literal: true

class CharacterDescriptionSectionComponent < ApplicationComponent
  attr_reader :character

  def initialize(character:)
    @character = character
  end
end
