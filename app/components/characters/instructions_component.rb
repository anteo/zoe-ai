# frozen_string_literal: true

module Characters
  class InstructionsComponent < ApplicationComponent
    attr_reader :character

    def initialize(character:)
      @character = character
    end

    def existing_instructions_json
      character.instructions.active.ordered.map { { id: it.id, content: it.content } }.to_json
    end
  end
end
