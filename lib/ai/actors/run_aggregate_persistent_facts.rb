module AI::Actors
  class RunAggregatePersistentFacts < Actor
    input :logger, default: -> { Rails.logger }

    def call
      Character.find_each do |current_character|
        partner_ids = Fact.where(character: current_character).distinct.pluck(:partner_id).compact - [current_character.id]
        partner_ids.each do |partner_id|
          current_partner = Character.find_by(id: partner_id)
          next unless current_partner

          AggregatePersistentFacts.call(character: current_character, partner: current_partner, logger:)
        end
      end
    end
  end
end
