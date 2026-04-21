# frozen_string_literal: true

class CharacterFormModalComponent < ApplicationComponent
  attr_reader :character

  def initialize(character:)
    @character = character
  end
end
