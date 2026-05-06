require "test_helper"

class EnqueueFactAggregateSummariesJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper
  fixtures :characters, :users, :characters_users, :topics, :chats

  test "enqueues pending and failed month summaries" do
    character, partner, topic = build_context

    pending_month = create_aggregate!(
      character:,
      partner:,
      topic:,
      kind: "month",
      anchor_month: Date.new(2026, 4, 1),
      summary_status: "pending"
    )
    failed_month = create_aggregate!(
      character:,
      partner:,
      topic:,
      kind: "month",
      anchor_month: Date.new(2026, 3, 1),
      summary_status: "failed"
    )
    create_aggregate!(
      character:,
      partner:,
      topic:,
      kind: "month",
      anchor_month: Date.new(2026, 2, 1),
      summary_status: "done"
    )

    with_test_queue_adapter do
      assert_enqueued_with(job: SummarizeFactAggregateJob, args: [ pending_month ]) do
        assert_enqueued_with(job: SummarizeFactAggregateJob, args: [ failed_month ]) do
          assert_enqueued_jobs 2, only: SummarizeFactAggregateJob do
            EnqueueFactAggregateSummariesJob.perform_now
          end
        end
      end
    end
  end

  test "enqueues only ready pending and failed band summaries" do
    character, partner, topic = build_context

    ready_pending_band = create_aggregate!(
      character:,
      partner:,
      topic:,
      kind: "m0_3",
      anchor_month: Date.new(2026, 4, 1),
      summary_status: "pending"
    )
    create_aggregate!(
      character:,
      partner:,
      topic:,
      kind: "month",
      anchor_month: Date.new(2026, 4, 1),
      summary_status: "done",
      parent: ready_pending_band
    )

    ready_failed_band = create_aggregate!(
      character:,
      partner:,
      topic:,
      kind: "m3_6",
      anchor_month: Date.new(2026, 4, 1),
      summary_status: "failed"
    )
    create_aggregate!(
      character:,
      partner:,
      topic:,
      kind: "month",
      anchor_month: Date.new(2026, 1, 1),
      summary_status: "done",
      parent: ready_failed_band
    )

    blocked_band = create_aggregate!(
      character:,
      partner:,
      topic:,
      kind: "m6_12",
      anchor_month: Date.new(2026, 4, 1),
      summary_status: "pending"
    )
    create_aggregate!(
      character:,
      partner:,
      topic:,
      kind: "month",
      anchor_month: Date.new(2025, 10, 1),
      summary_status: "pending",
      parent: blocked_band
    )

    create_aggregate!(
      character:,
      partner:,
      topic:,
      kind: "year_2024",
      anchor_month: Date.new(2026, 4, 1),
      summary_status: "pending"
    )

    with_test_queue_adapter do
      assert_enqueued_with(job: SummarizeFactAggregateJob, args: [ ready_pending_band ]) do
        assert_enqueued_with(job: SummarizeFactAggregateJob, args: [ ready_failed_band ]) do
          assert_enqueued_jobs 3, only: SummarizeFactAggregateJob do
            EnqueueFactAggregateSummariesJob.perform_now
          end
        end
      end
    end
  end

  private

  def build_context
    [ characters(:anton_human), chats(:anton_with_zoe).partner, topics(:work) ]
  end

  def create_aggregate!(character:, partner:, topic:, kind:, anchor_month:, summary_status:, parent: nil)
    FactAggregate.create!(
      character:,
      partner:,
      topic:,
      parent:,
      kind:,
      anchor_month:,
      body: "#{kind} #{anchor_month}",
      facts_count: 1,
      source_updated_at: Time.current,
      summary_status:,
      summary_source_updated_at: summary_status == "done" ? Time.current : nil,
      summary: summary_status == "done" ? "Summary #{kind} #{anchor_month}" : nil
    )
  end

  def with_test_queue_adapter
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
    yield
  ensure
    clear_enqueued_jobs
    clear_performed_jobs
    ActiveJob::Base.queue_adapter = original_adapter
  end
end
