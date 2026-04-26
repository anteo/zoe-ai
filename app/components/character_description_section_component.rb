# frozen_string_literal: true

class CharacterDescriptionSectionComponent < ApplicationComponent
  attr_reader :character

  def initialize(character:)
    @character = character
  end

  def description
    @description ||= AI::Actors::DescribeCharacter.result(character:, mode: :markdown, period_order: :desc).description.to_s
  end
end
