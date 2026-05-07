require "test_helper"

class FactAggregateTest < ActiveSupport::TestCase
  fixtures :characters, :users, :chats, :topics

  test "anchor month is required" do
    aggregate = FactAggregate.new(
      character: characters(:anton_human),
      partner: characters(:zoe_default),
      topic: topics(:work),
      kind: "month",
      body: "Aggregate body",
      facts_count: 1,
      source_updated_at: Time.zone.now
    )

    assert_not aggregate.valid?
    assert_includes aggregate.errors[:anchor_month], "can't be blank"
  end
end
