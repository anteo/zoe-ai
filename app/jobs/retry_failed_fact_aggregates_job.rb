class RetryFailedFactAggregatesJob < ApplicationJob
  limits_concurrency to: 1,
                     key: -> { "retry_failed_fact_aggregates_#{Date.current}" }

  def perform
    retry_failed_months
    retry_failed_ready_bands
  end

  private

  def retry_failed_months
    FactAggregate.months.failed.find_each do |aggregate|
      SummarizeFactAggregateJob.perform_later(aggregate)
    end
  end

  def retry_failed_ready_bands
    FactAggregate.bands
                 .failed
                 .includes(:children)
                 .find_each do |aggregate|
      next if aggregate.children.empty?
      next unless aggregate.children.all?(&:done?)

      SummarizeFactAggregateJob.perform_later(aggregate)
    end
  end
end
