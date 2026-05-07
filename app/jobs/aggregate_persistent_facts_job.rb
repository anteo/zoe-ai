class AggregatePersistentFactsJob < ApplicationJob
  limits_concurrency to: 1,
                     key: lambda { |character = nil, partner = nil|
                       "aggregate_persistent_facts_#{character&.id || "all"}_#{partner&.id || "all"}_#{Date.current.beginning_of_month}"
                     }

  def perform(character: nil, partner: nil)
    if character && partner
      AI::Actors::AggregatePersistentFacts.call(character:, partner:, logger:)
    else
      AI::Actors::RunAggregatePersistentFacts.call(logger:)
    end
  end
end
