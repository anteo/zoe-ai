class EnqueueFactAggregateSummariesJob < ApplicationJob
  limits_concurrency to: 1,
                     key: -> { "enqueue_fact_aggregate_summaries_#{Date.current}" }

  def perform
    enqueue_months
    enqueue_ready_bands
  end

  private

  def enqueue_months
    FactAggregate.months
                 .find_each do |aggregate|
      next unless aggregate.needs_summary_refresh?

      SummarizeFactAggregateJob.perform_later(aggregate)
    end
  end

  def enqueue_ready_bands
    FactAggregate.bands
                 .includes(:children)
                 .find_each do |aggregate|
      next unless aggregate.needs_summary_refresh?

      SummarizeFactAggregateJob.perform_later(aggregate)
    end
  end
end
