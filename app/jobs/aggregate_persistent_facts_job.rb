class AggregatePersistentFactsJob < ApplicationJob
  limits_concurrency to: 1,
                     key: lambda { |character = nil, partner = nil|
                       "aggregate_persistent_facts_#{character&.id || "all"}_#{partner&.id || "all"}_#{Date.current.beginning_of_month}"
                     }

  def perform(character = nil, partner = nil)
    if character && partner
      AI::Actors::AggregatePersistentFacts.call(character:, partner:, logger:)
      return
    end

    Character.find_each do |current_character|
      partner_ids = Fact.where(character: current_character).distinct.pluck(:partner_id).compact
      partner_ids.each do |partner_id|
        current_partner = Character.find_by(id: partner_id)
        next unless current_partner
        self.class.perform_later(current_character, current_partner)
      end
    end
  end
end
