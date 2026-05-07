module Characters
  class InstructionsComponent < ApplicationComponent
    attr_reader :character, :editable, :partner

    def initialize(character:, partner: nil, editable: false)
      @character = character
      @editable = editable
      @partner = partner
    end

    def existing_instructions_json
      character.instructions.active.ordered.map { { id: it.id, content: it.content } }.to_json
    end
  end
end
