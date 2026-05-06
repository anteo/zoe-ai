class EnqueueFactAggregateSummariesJob < ApplicationJob
  SUMMARY_STATUSES = %w[pending failed].freeze

  limits_concurrency to: 1,
                     key: -> { "enqueue_fact_aggregate_summaries_#{Date.current}" }

  def perform
    enqueue_months
    enqueue_ready_bands
  end

  private

  def enqueue_months
    FactAggregate.months
                 .where(summary_status: SUMMARY_STATUSES)
                 .find_each do |aggregate|
      SummarizeFactAggregateJob.perform_later(aggregate)
    end
  end

  def enqueue_ready_bands
    FactAggregate.bands
                 .where(summary_status: SUMMARY_STATUSES)
                 .includes(:children)
                 .find_each do |aggregate|
      next if aggregate.children.empty?
      next unless aggregate.children.all?(&:done?)

      SummarizeFactAggregateJob.perform_later(aggregate)
    end
  end
end
