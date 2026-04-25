class AggregatePersistentFactsJob < ApplicationJob
  limits_concurrency to: 1,
                     key: ->(character = nil) { "aggregate_persistent_facts_#{character&.id || "all"}_#{Date.current.beginning_of_month}" }

  def perform(character = nil)
    if character
      AI::Actors::AggregatePersistentFacts.call(character:)
      return
    end

    Character.find_each do |current_character|
      self.class.perform_later(current_character)
    end
  end
end
