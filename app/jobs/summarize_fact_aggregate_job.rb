class SummarizeFactAggregateJob < ApplicationJob
  limits_concurrency to: 1,
                     key: ->(*) { "summarize_fact_aggregate" }

  def perform(fact_aggregate)
    AI::Actors::SummarizeFactAggregate.call(fact_aggregate:, logger:)
  end
end
