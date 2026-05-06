module Characters
  class DescriptionComponent < ApplicationComponent
    attr_reader :character, :partner

    def initialize(character:, partner: nil)
      @character = character
      @partner = partner
    end

    def description
      @description ||= AI::Actors::DescribeCharacter.result(character:, partner:, mode: :markdown, period_order: :desc).description.to_s
    end
  end
end
