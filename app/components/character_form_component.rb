# frozen_string_literal: true

class CharacterFormComponent < ApplicationComponent
  attr_reader :character

  def initialize(character:)
    @character = character
  end

  def avatar_preview_style
    return unless character.avatar.attached?

    "background-image: url('#{helpers.url_for(character.avatar.variant(resize_to_limit: [ 64, 64 ]))}')"
  end

  def editable_name?
    character.new_record?
  end
end
