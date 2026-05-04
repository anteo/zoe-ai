require "test_helper"

class DescribeCharacterTest < ActiveSupport::TestCase
  fixtures :characters, :topics

  test "renders markdown from current aggregate bands" do
    character = characters(:anton_human)
    anchor_month = Date.new(2026, 4, 1)

    create_aggregate!(
      character:,
      topic: topics(:work),
      kind: "m0_3",
      anchor_month:,
      summary: "Anton works on Zoe every day."
    )
    create_aggregate!(
      character:,
      topic: topics(:hobby),
      kind: "m6_12",
      anchor_month:,
      body: "## October 2025\nAnton swims on weekends."
    )

    description = AI::Actors::DescribeCharacter.result(character:, partner: characters(:zoe_default), mode: :markdown).description

    assert_includes description, "## Last 3 months"
    assert_includes description, "### Work"
    assert_includes description, "Anton works on Zoe every day."
    assert_includes description, "## 6 to 12 months ago"
    assert_includes description, "### Hobby"
    assert_includes description, "Anton swims on weekends."
  end

  test "renders xml and escapes topic and content values" do
    character = characters(:anton_human)
    anchor_month = Date.new(2026, 4, 1)
    topic = Topic.create!(name: "R&D <AI>")

    create_aggregate!(
      character:,
      topic:,
      kind: "m0_3",
      anchor_month:,
      summary: "Anton uses tools & adapters."
    )

    description = AI::Actors::DescribeCharacter.result(character:, partner: characters(:zoe_default), mode: :xml).description

    assert_includes description, "<period from=\"February 2026\" to=\"April 2026\">"
    assert_includes description, "<topic name=\"R&amp;D &lt;AI&gt;\">"
    assert_includes description, "Anton uses tools &amp; adapters."
  end

  test "uses latest anchor month bands only" do
    character = characters(:anton_human)
    topic = topics(:work)

    create_aggregate!(
      character:,
      topic:,
      kind: "m0_3",
      anchor_month: Date.new(2026, 3, 1),
      summary: "Old summary"
    )
    create_aggregate!(
      character:,
      topic:,
      kind: "m0_3",
      anchor_month: Date.new(2026, 4, 1),
      summary: "Current summary"
    )

    description = AI::Actors::DescribeCharacter.result(character:, partner: characters(:zoe_default), mode: :markdown).description

    assert_includes description, "Current summary"
    assert_not_includes description, "Old summary"
  end

  test "renders periods oldest first by default" do
    character = characters(:anton_human)
    anchor_month = Date.new(2026, 4, 1)

    create_aggregate!(
      character:,
      topic: topics(:work),
      kind: "m0_3",
      anchor_month:,
      summary: "Current summary"
    )
    create_aggregate!(
      character:,
      topic: topics(:hobby),
      kind: "m6_12",
      anchor_month:,
      summary: "Older summary"
    )

    description = AI::Actors::DescribeCharacter.result(character:, partner: characters(:zoe_default), mode: :markdown).description

    assert_operator description.index("## 6 to 12 months ago"), :<, description.index("## Last 3 months")
  end

  test "can render periods newest first" do
    character = characters(:anton_human)
    anchor_month = Date.new(2026, 4, 1)

    create_aggregate!(
      character:,
      topic: topics(:work),
      kind: "m0_3",
      anchor_month:,
      summary: "Current summary"
    )
    create_aggregate!(
      character:,
      topic: topics(:hobby),
      kind: "m6_12",
      anchor_month:,
      summary: "Older summary"
    )

    description = AI::Actors::DescribeCharacter.result(character:, partner: characters(:zoe_default), mode: :markdown, period_order: :desc).description

    assert_operator description.index("## Last 3 months"), :<, description.index("## 6 to 12 months ago")
  end

  test "returns empty string when no band aggregates exist" do
    character = characters(:anton_human)
    topic = topics(:work)

    create_aggregate!(
      character:,
      topic:,
      kind: "month",
      anchor_month: Date.new(2026, 4, 1),
      summary: "Month-only summary"
    )

    description = AI::Actors::DescribeCharacter.result(character:, partner: characters(:zoe_default), mode: :markdown).description
    assert_equal "", description
  end

  private

  def create_aggregate!(character:, topic:, kind:, anchor_month:, summary: nil, body: "Body", partner: characters(:zoe_default))
    FactAggregate.create!(
      character:,
      partner:,
      topic:,
      kind:,
      anchor_month:,
      body:,
      summary:,
      facts_count: 1,
      source_updated_at: Time.zone.now
    )
  end
end
