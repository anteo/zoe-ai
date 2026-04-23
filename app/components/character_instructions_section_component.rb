# frozen_string_literal: true

class CharacterInstructionsSectionComponent < ApplicationComponent
  attr_reader :character

  def initialize(character:)
    @character = character
  end

  def existing_instructions_json
    character.instructions.order(:created_at, :id).map { { id: it.id, content: it.content } }.to_json
  end
end
