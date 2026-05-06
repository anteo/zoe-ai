require "test_helper"

class AggregatePersistentFactsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  fixtures :characters, :users, :characters_users, :topics, :chats

  test "same-anchor refresh only updates stale related bands" do
    anchor_month = Date.new(2026, 4, 1)
    character, chat, topic_work, topic_hobby = build_character_context

    create_fact!(
      character:,
      chat:,
      topic: topic_work,
      content: "Anton works on Zoe every day.",
      mentioned_at: Time.zone.local(2026, 4, 10, 12, 0, 0)
    )
    create_fact!(
      character:,
      chat:,
      topic: topic_hobby,
      content: "Anton swims on weekends.",
      mentioned_at: Time.zone.local(2025, 10, 8, 12, 0, 0)
    )

    travel_to Time.zone.local(2026, 4, 23, 9, 0, 0) do
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    work_band = character.fact_aggregates.find_by!(kind: "m0_3", topic: topic_work, anchor_month:)
    hobby_band = character.fact_aggregates.find_by!(kind: "m6_12", topic: topic_hobby, anchor_month:)

    original_work_updated_at = work_band.updated_at
    original_hobby_updated_at = hobby_band.updated_at

    travel_to Time.zone.local(2026, 4, 23, 10, 0, 0) do
      work_fact = character.facts.find_by!(topic: topic_work)
      work_fact.update!(content: "Anton works on Zoe every single day.")

      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    assert_operator work_band.reload.updated_at, :>, original_work_updated_at
    assert_includes work_band.body, "Anton works on Zoe every single day."
    assert_equal original_hobby_updated_at, hobby_band.reload.updated_at
  end

  test "month change rotates current bands" do
    april_anchor = Date.new(2026, 4, 1)
    may_anchor = Date.new(2026, 5, 1)
    character, chat, topic_work, topic_hobby = build_character_context

    create_fact!(
      character:,
      chat:,
      topic: topic_work,
      content: "Anton works on Zoe every day.",
      mentioned_at: Time.zone.local(2026, 4, 10, 12, 0, 0)
    )
    create_fact!(
      character:,
      chat:,
      topic: topic_hobby,
      content: "Anton swims on weekends.",
      mentioned_at: Time.zone.local(2025, 10, 8, 12, 0, 0)
    )

    travel_to Time.zone.local(2026, 4, 23, 9, 0, 0) do
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    assert character.fact_aggregates.exists?(kind: "m0_3", topic: topic_work, anchor_month: april_anchor)
    assert character.fact_aggregates.exists?(kind: "m6_12", topic: topic_hobby, anchor_month: april_anchor)

    travel_to Time.zone.local(2026, 5, 2, 9, 0, 0) do
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    assert_not character.fact_aggregates.bands.exists?(anchor_month: april_anchor)
    work_band = character.fact_aggregates.find_by!(kind: "m0_3", topic: topic_work, anchor_month: may_anchor)
    hobby_band = character.fact_aggregates.find_by!(kind: "m6_12", topic: topic_hobby, anchor_month: may_anchor)
    work_month = character.fact_aggregates.find_by!(kind: "month", topic: topic_work, anchor_month: Date.new(2026, 4, 1))
    hobby_month = character.fact_aggregates.find_by!(kind: "month", topic: topic_hobby, anchor_month: Date.new(2025, 10, 1))

    assert_equal work_band, work_month.parent
    assert_equal hobby_band, hobby_month.parent
    assert_equal [ work_month ], work_band.children.to_a
    assert_equal [ hobby_month ], hobby_band.children.to_a
  end

  test "double run with same anchor and unchanged facts is a no-op" do
    anchor_month = Date.new(2026, 4, 1)
    character, chat, topic_work, = build_character_context

    create_fact!(
      character:,
      chat:,
      topic: topic_work,
      content: "Anton works on Zoe every day.",
      mentioned_at: Time.zone.local(2026, 4, 10, 12, 0, 0)
    )

    travel_to Time.zone.local(2026, 4, 23, 9, 0, 0) do
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    first_snapshot = character.fact_aggregates
                              .order(:id)
                              .pluck(:id, :kind, :slot_key, :body, :facts_count, :source_updated_at, :updated_at)

    travel_to Time.zone.local(2026, 4, 23, 10, 0, 0) do
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    second_snapshot = character.fact_aggregates
                               .order(:id)
                               .pluck(:id, :kind, :slot_key, :body, :facts_count, :source_updated_at, :updated_at)

    assert_equal first_snapshot, second_snapshot
  end

  test "month is refreshed only when stale" do
    anchor_month = Date.new(2026, 4, 1)
    character, chat, topic_work, = build_character_context

    create_fact!(
      character:,
      chat:,
      topic: topic_work,
      content: "Anton works on Zoe every day.",
      mentioned_at: Time.zone.local(2026, 4, 10, 12, 0, 0)
    )

    travel_to Time.zone.local(2026, 4, 23, 9, 0, 0) do
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    month = character.fact_aggregates.find_by!(kind: "month", topic: topic_work, anchor_month:)
    original_updated_at = month.updated_at

    travel_to Time.zone.local(2026, 4, 23, 10, 0, 0) do
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    assert_equal original_updated_at, month.reload.updated_at

    travel_to Time.zone.local(2026, 4, 23, 11, 0, 0) do
      month.update_columns(stale: true, updated_at: Time.current)
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    assert_operator month.reload.updated_at, :>, original_updated_at
    assert_equal false, month.stale?
  end

  test "month aggregates are linked to their band parent" do
    anchor_month = Date.new(2026, 4, 1)
    character, chat, topic_work, = build_character_context

    create_fact!(
      character:,
      chat:,
      topic: topic_work,
      content: "Anton works on Zoe every day.",
      mentioned_at: Time.zone.local(2026, 4, 10, 12, 0, 0)
    )
    create_fact!(
      character:,
      chat:,
      topic: topic_work,
      content: "Anton started migration planning.",
      mentioned_at: Time.zone.local(2025, 9, 12, 12, 0, 0)
    )

    travel_to Time.zone.local(2026, 4, 23, 9, 0, 0) do
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    current_month = character.fact_aggregates.find_by!(kind: "month", topic: topic_work, anchor_month:)
    historical_month = character.fact_aggregates.find_by!(kind: "month", topic: topic_work, anchor_month: Date.new(2025, 9, 1))
    current_band = character.fact_aggregates.find_by!(kind: "m0_3", topic: topic_work, anchor_month:)
    historical_band = character.fact_aggregates.find_by!(kind: "m6_12", topic: topic_work, anchor_month:)

    assert_equal current_band, current_month.parent
    assert_equal historical_band, historical_month.parent
    assert_equal [ current_month ], current_band.children.to_a
    assert_equal [ historical_month ], historical_band.children.to_a
    assert_equal current_band.children.order(:anchor_month).to_a, current_band.source_records.to_a
  end

  test "aggregation does not enqueue summarization for changed month aggregates" do
    character, chat, topic_work, = build_character_context

    create_fact!(
      character:,
      chat:,
      topic: topic_work,
      content: "Anton works on Zoe every day.",
      mentioned_at: Time.zone.local(2026, 4, 10, 12, 0, 0)
    )

    with_test_queue_adapter do
      assert_enqueued_jobs 0, only: SummarizeFactAggregateJob do
        travel_to Time.zone.local(2026, 4, 23, 9, 0, 0) do
          AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
        end
      end
    end
  end

  test "month summarization enqueues parent band when all children are summarized" do
    anchor_month = Date.new(2026, 4, 1)
    character, chat, topic_work, = build_character_context

    create_fact!(
      character:,
      chat:,
      topic: topic_work,
      content: "Anton works on Zoe every day.",
      mentioned_at: Time.zone.local(2026, 4, 10, 12, 0, 0)
    )
    create_fact!(
      character:,
      chat:,
      topic: topic_work,
      content: "Anton started migration planning.",
      mentioned_at: Time.zone.local(2026, 3, 12, 12, 0, 0)
    )

    travel_to Time.zone.local(2026, 4, 23, 9, 0, 0) do
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end
    clear_enqueued_jobs

    band = character.fact_aggregates.find_by!(kind: "m0_3", topic: topic_work, anchor_month:)
    summarized_month = character.fact_aggregates.find_by!(kind: "month", topic: topic_work, anchor_month: Date.new(2026, 3, 1))
    pending_month = character.fact_aggregates.find_by!(kind: "month", topic: topic_work, anchor_month: Date.new(2026, 4, 1))

    summarized_month.update!(
      summary: "Anton started migration planning.",
      summary_status: "done",
      summary_source_updated_at: summarized_month.source_updated_at
    )

    response = Struct.new(:content).new({ "summary" => "Anton works on Zoe every day." })
    agent_chat = Class.new do
      define_method(:ask) { |_| response }
    end.new

    with_stubbed_agent_chat(agent_chat) do
      with_test_queue_adapter do
        assert_enqueued_with(job: SummarizeFactAggregateJob, args: [ band ]) do
          SummarizeFactAggregateJob.perform_now(pending_month)
        end
      end
    end

    assert pending_month.reload.done?
  end

  test "deleting fact refreshes and removes now-empty aggregates" do
    anchor_month = Date.new(2026, 4, 1)
    character, chat, topic_work, = build_character_context

    fact = create_fact!(
      character:,
      chat:,
      topic: topic_work,
      content: "Anton works on Zoe every day.",
      mentioned_at: Time.zone.local(2026, 4, 10, 12, 0, 0)
    )

    travel_to Time.zone.local(2026, 4, 23, 9, 0, 0) do
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    assert character.fact_aggregates.exists?(kind: "month", topic: topic_work, anchor_month: Date.new(2026, 4, 1))
    assert character.fact_aggregates.exists?(kind: "m0_3", topic: topic_work, anchor_month:)

    fact.destroy!
    travel_to Time.zone.local(2026, 4, 23, 10, 0, 0) do
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    assert_not character.fact_aggregates.exists?(kind: "month", topic: topic_work, anchor_month: Date.new(2026, 4, 1))
    assert_not character.fact_aggregates.exists?(kind: "m0_3", topic: topic_work, anchor_month:)
  end

  test "deleting one of multiple facts refreshes band instead of deleting it" do
    anchor_month = Date.new(2026, 4, 1)
    character, chat, topic_work, = build_character_context

    fact_one = create_fact!(
      character:,
      chat:,
      topic: topic_work,
      content: "Anton works on Zoe every day.",
      mentioned_at: Time.zone.local(2026, 4, 10, 12, 0, 0)
    )
    create_fact!(
      character:,
      chat:,
      topic: topic_work,
      content: "Anton mentors the team weekly.",
      mentioned_at: Time.zone.local(2026, 4, 12, 12, 0, 0)
    )

    travel_to Time.zone.local(2026, 4, 23, 9, 0, 0) do
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    band = character.fact_aggregates.find_by!(kind: "m0_3", topic: topic_work, anchor_month:)
    month = character.fact_aggregates.find_by!(kind: "month", topic: topic_work, anchor_month: Date.new(2026, 4, 1))
    original_updated_at = band.updated_at

    fact_one.destroy!

    travel_to Time.zone.local(2026, 4, 23, 10, 0, 0) do
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    assert character.fact_aggregates.exists?(kind: "m0_3", topic: topic_work, anchor_month:)
    assert_equal 1, month.reload.facts_count
    assert_equal 1, band.reload.facts_count
    assert_operator band.updated_at, :>, original_updated_at
    assert_not_includes band.body, "Anton works on Zoe every day."
    assert_includes band.body, "Anton mentors the team weekly."
  end

  test "deleting fact in previous-period month refreshes related historical band" do
    anchor_month = Date.new(2026, 4, 1)
    character, chat, topic_work, = build_character_context

    fact_october = create_fact!(
      character:,
      chat:,
      topic: topic_work,
      content: "Anton delivered Q4 roadmap.",
      mentioned_at: Time.zone.local(2025, 10, 10, 12, 0, 0)
    )
    create_fact!(
      character:,
      chat:,
      topic: topic_work,
      content: "Anton started migration planning.",
      mentioned_at: Time.zone.local(2025, 9, 12, 12, 0, 0)
    )

    travel_to Time.zone.local(2026, 4, 23, 9, 0, 0) do
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    band = character.fact_aggregates.find_by!(kind: "m6_12", topic: topic_work, anchor_month:)
    october_month = character.fact_aggregates.find_by!(kind: "month", topic: topic_work, anchor_month: Date.new(2025, 10, 1))
    original_updated_at = band.updated_at

    fact_october.destroy!

    travel_to Time.zone.local(2026, 4, 23, 10, 0, 0) do
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    assert_not character.fact_aggregates.exists?(id: october_month.id)
    assert character.fact_aggregates.exists?(kind: "m6_12", topic: topic_work, anchor_month:)
    assert_equal 1, band.reload.facts_count
    assert_operator band.updated_at, :>, original_updated_at
    assert_not_includes band.body, "Anton delivered Q4 roadmap."
    assert_includes band.body, "Anton started migration planning."
  end

  test "same-month delete without time travel updates month and band" do
    anchor_month = Date.new(2026, 4, 1)
    character, chat, topic_work, = build_character_context

    fact_one = create_fact!(
      character:,
      chat:,
      topic: topic_work,
      content: "Anton works on Zoe every day.",
      mentioned_at: Time.zone.local(2026, 4, 10, 12, 0, 0)
    )
    create_fact!(
      character:,
      chat:,
      topic: topic_work,
      content: "Anton mentors the team weekly.",
      mentioned_at: Time.zone.local(2026, 4, 12, 12, 0, 0)
    )

    travel_to Time.zone.local(2026, 4, 23, 9, 0, 0) do
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    month = character.fact_aggregates.find_by!(kind: "month", topic: topic_work, anchor_month: Date.new(2026, 4, 1))
    band = character.fact_aggregates.find_by!(kind: "m0_3", topic: topic_work, anchor_month:)
    assert_equal 2, month.facts_count
    assert_equal 2, band.facts_count

    fact_one.destroy!
    travel_to Time.zone.local(2026, 4, 23, 10, 0, 0) do
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    assert_equal 1, month.reload.facts_count
    assert_equal 1, band.reload.facts_count
    assert_not_includes month.body, "Anton works on Zoe every day."
    assert_includes month.body, "Anton mentors the team weekly."
    assert_not_includes band.body, "Anton works on Zoe every day."
    assert_includes band.body, "Anton mentors the team weekly."
  end

  test "very old months are grouped into stable year buckets" do
    anchor_month = Date.new(2026, 4, 1)
    character, chat, topic_work, = build_character_context

    create_fact!(
      character:,
      chat:,
      topic: topic_work,
      content: "Anton rebuilt the first prototype.",
      mentioned_at: Time.zone.local(2023, 6, 10, 12, 0, 0)
    )
    create_fact!(
      character:,
      chat:,
      topic: topic_work,
      content: "Anton shipped the early beta.",
      mentioned_at: Time.zone.local(2023, 9, 12, 12, 0, 0)
    )

    travel_to Time.zone.local(2026, 4, 23, 9, 0, 0) do
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    year_band = character.fact_aggregates.find_by!(kind: "year_2023", topic: topic_work, anchor_month:)

    assert_equal 2, year_band.facts_count
    assert_includes year_band.body, "Anton rebuilt the first prototype."
    assert_includes year_band.body, "Anton shipped the early beta."
  end

  test "stale old month refreshes current bands without rebuilding historical anchor" do
    april_anchor = Date.new(2026, 4, 1)
    character, chat, topic_work, = build_character_context

    create_fact!(
      character:,
      chat:,
      topic: topic_work,
      content: "Anton works on Zoe every day.",
      mentioned_at: Time.zone.local(2026, 4, 10, 12, 0, 0)
    )
    march_fact = create_fact!(
      character:,
      chat:,
      topic: topic_work,
      content: "Anton was wrapping up Q1 tasks.",
      mentioned_at: Time.zone.local(2026, 3, 12, 12, 0, 0)
    )

    travel_to Time.zone.local(2026, 4, 23, 9, 0, 0) do
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    assert character.fact_aggregates.exists?(kind: "m0_3", topic: topic_work, anchor_month: april_anchor)
    original_month = character.fact_aggregates.find_by!(kind: "month", topic: topic_work, anchor_month: Date.new(2026, 3, 1))

    travel_to Time.zone.local(2026, 4, 23, 10, 0, 0) do
      march_fact.update!(content: "Anton closed Q1 strongly.")
      AI::Actors::AggregatePersistentFacts.call(character:, partner: chat.partner)
    end

    assert character.fact_aggregates.exists?(kind: "m0_3", topic: topic_work, anchor_month: april_anchor)
    assert_includes original_month.reload.body, "Anton closed Q1 strongly."
  end

  private

  def build_character_context
    [
      characters(:anton_human),
      chats(:anton_with_zoe),
      topics(:work),
      topics(:hobby)
    ]
  end

  def create_fact!(character:, chat:, topic:, content:, mentioned_at:)
    message = chat.messages.create!(role: "user", content:, created_at: mentioned_at, updated_at: mentioned_at)

    Fact.create!(
      character:,
      partner: chat.partner,
      author: character,
      message:,
      chat:,
      topic:,
      content:,
      kind: "attribute",
      time: "present",
      persistent: true,
      mentioned_at:
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

  def with_stubbed_agent_chat(agent_chat)
    singleton_class = AI::Agents::SummarizeFactAggregate.singleton_class
    original_method = singleton_class.instance_method(:chat)
    singleton_class.define_method(:chat) { |**| agent_chat }
    yield
  ensure
    singleton_class&.define_method(:chat, original_method) if original_method
  end
end
