require "test_helper"

class FactTest < ActiveSupport::TestCase
  fixtures :characters, :users, :chats, :topics

  test "create marks matching persistent month aggregate stale" do
    chat = chats(:anton_with_zoe)
    aggregate = create_month_aggregate!(topic: topics(:work), anchor_month: Date.new(2026, 4, 1))

    assert_changes -> { aggregate.reload.stale? }, from: false, to: true do
      create_fact!(chat:, topic: topics(:work), mentioned_at: Time.zone.local(2026, 4, 10, 12, 0, 0))
    end
  end

  test "create does not mark aggregates stale for non-persistent facts" do
    chat = chats(:anton_with_zoe)
    aggregate = create_month_aggregate!(topic: topics(:work), anchor_month: Date.new(2026, 4, 1))

    assert_no_changes -> { aggregate.reload.stale? } do
      create_fact!(
        chat:,
        topic: topics(:work),
        mentioned_at: Time.zone.local(2026, 4, 10, 12, 0, 0),
        persistent: false
      )
    end
  end

  test "updating persistent fact to a different month and topic marks old and new aggregates stale" do
    chat = chats(:anton_with_zoe)
    old_aggregate = create_month_aggregate!(topic: topics(:work), anchor_month: Date.new(2026, 4, 1))
    new_aggregate = create_month_aggregate!(topic: topics(:hobby), anchor_month: Date.new(2026, 5, 1))
    fact = create_fact!(chat:, topic: topics(:work), mentioned_at: Time.zone.local(2026, 4, 10, 12, 0, 0))

    old_aggregate.update_columns(stale: false, updated_at: Time.current)
    new_aggregate.update_columns(stale: false, updated_at: Time.current)
    fact.reload

    assert_changes -> { [ old_aggregate.reload.stale?, new_aggregate.reload.stale? ] }, from: [ false, false ], to: [ true, true ] do
      fact.update!(
        topic: topics(:hobby),
        mentioned_at: Time.zone.local(2026, 5, 10, 12, 0, 0)
      )
    end
  end

  test "updating persistent fact to non-persistent marks only the previous aggregate stale" do
    chat = chats(:anton_with_zoe)
    old_aggregate = create_month_aggregate!(topic: topics(:work), anchor_month: Date.new(2026, 4, 1))
    new_aggregate = create_month_aggregate!(topic: topics(:hobby), anchor_month: Date.new(2026, 5, 1))
    fact = create_fact!(chat:, topic: topics(:work), mentioned_at: Time.zone.local(2026, 4, 10, 12, 0, 0))

    old_aggregate.update_columns(stale: false, updated_at: Time.current)
    new_aggregate.update_columns(stale: false, updated_at: Time.current)
    fact.reload

    assert_changes -> { [ old_aggregate.reload.stale?, new_aggregate.reload.stale? ] }, from: [ false, false ], to: [ true, false ] do
      fact.update!(
        topic: topics(:hobby),
        mentioned_at: Time.zone.local(2026, 5, 10, 12, 0, 0),
        persistent: false
      )
    end
  end

  test "destroy marks current persistent month aggregate stale" do
    chat = chats(:anton_with_zoe)
    aggregate = create_month_aggregate!(topic: topics(:work), anchor_month: Date.new(2026, 4, 1))
    fact = create_fact!(chat:, topic: topics(:work), mentioned_at: Time.zone.local(2026, 4, 10, 12, 0, 0))

    fact.reload
    aggregate.update_columns(stale: false, updated_at: Time.current)

    assert_changes -> { aggregate.reload.stale? }, from: false, to: true do
      fact.destroy!
    end
  end

  test "destroying chat marks associated persistent month aggregates stale" do
    chat = chats(:anton_with_zoe)
    aggregate = create_month_aggregate!(topic: topics(:work), anchor_month: Date.new(2026, 4, 1))
    create_fact!(chat:, topic: topics(:work), mentioned_at: Time.zone.local(2026, 4, 10, 12, 0, 0))

    aggregate.update_columns(stale: false, updated_at: Time.current)

    assert_changes -> { aggregate.reload.stale? }, from: false, to: true do
      chat.destroy!
    end
  end

  test "destroying later messages marks associated persistent month aggregates stale" do
    chat = chats(:anton_with_zoe)
    first_message = chat.messages.create!(
      role: "user",
      content: "First message",
      created_at: Time.zone.local(2026, 4, 10, 12, 0, 0),
      updated_at: Time.zone.local(2026, 4, 10, 12, 0, 0)
    )
    aggregate = create_month_aggregate!(topic: topics(:work), anchor_month: Date.new(2026, 4, 1))

    create_fact!(
      chat:,
      topic: topics(:work),
      mentioned_at: Time.zone.local(2026, 4, 11, 12, 0, 0)
    )

    aggregate.update_columns(stale: false, updated_at: Time.current)

    assert_changes -> { aggregate.reload.stale? }, from: false, to: true do
      first_message.destroy_later_messages
    end
  end

  test "force re-extraction marks deleted persistent month aggregates stale" do
    chat = chats(:anton_with_zoe)
    aggregate = create_month_aggregate!(topic: topics(:work), anchor_month: Date.new(2026, 4, 1))
    message = chat.messages.create!(
      role: "user",
      content: "Original fact source",
      created_at: Time.zone.local(2026, 4, 10, 12, 0, 0),
      updated_at: Time.zone.local(2026, 4, 10, 12, 0, 0),
      facts_extracted: true
    )
    Fact.create!(
      character: chat.character,
      partner: chat.partner,
      author: chat.character,
      message:,
      chat:,
      topic: topics(:work),
      content: "Anton fact",
      kind: "attribute",
      time: "present",
      persistent: true,
      mentioned_at: message.created_at
    )

    aggregate.update_columns(stale: false, updated_at: Time.current)

    with_stubbed_extract_facts_chat(FakeExtractFactsChat.new([ { "facts" => [] } ])) do
      assert_changes -> { aggregate.reload.stale? }, from: false, to: true do
        AI::Actors::ExtractFacts.call(chat:, force: true)
      end
    end
  end

  private

  def create_fact!(chat:, topic:, mentioned_at:, persistent: true)
    message = chat.messages.create!(
      role: "user",
      content: "Fact source",
      created_at: mentioned_at,
      updated_at: mentioned_at
    )

    Fact.create!(
      character: chat.character,
      partner: chat.partner,
      author: chat.character,
      message:,
      chat:,
      topic:,
      content: "Anton fact",
      kind: "attribute",
      time: "present",
      persistent:,
      mentioned_at:
    )
  end

  def create_month_aggregate!(topic:, anchor_month:)
    chat = chats(:anton_with_zoe)

    FactAggregate.create!(
      character: chat.character,
      partner: chat.partner,
      topic:,
      kind: "month",
      anchor_month:,
      body: "Aggregate body",
      facts_count: 1,
      source_updated_at: Time.zone.now
    )
  end

  def with_stubbed_extract_facts_chat(agent_chat)
    singleton_class = AI::Agents::ExtractFacts.singleton_class
    original_method = singleton_class.instance_method(:chat)
    singleton_class.define_method(:chat) { |**| agent_chat }
    yield
  ensure
    singleton_class&.define_method(:chat, original_method) if original_method
  end

  class FakeExtractFactsChat
    attr_reader :messages

    def initialize(payloads)
      @payloads = payloads.dup
      @messages = []
    end

    def instructions
      "test instructions"
    end

    def add_message(role:, content:)
      messages << { role:, content: }
    end

    def complete
      Struct.new(:content).new(@payloads.shift)
    end
  end
end
