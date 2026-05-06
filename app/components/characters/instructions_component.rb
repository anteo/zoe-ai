module Characters
  class InstructionsComponent < ApplicationComponent
    attr_reader :character, :partner

    def initialize(character:, partner: nil)
      @character = character
      @partner = partner
    end

    def existing_instructions_json
      character.instructions.active.ordered.map { { id: it.id, content: it.content } }.to_json
    end
  end
end
