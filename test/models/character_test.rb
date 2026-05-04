require "test_helper"

class CharacterTest < ActiveSupport::TestCase
  fixtures :characters, :users, :chats, :topics

  test "prompt_role returns you for current partner" do
    chat = chats(:anton_with_zoe)

    assert_equal "you", chat.partner.prompt_role(chat)
  end

  test "prompt_role returns interlocutor for current chat character" do
    chat = chats(:anton_with_zoe)

    assert_equal "interlocutor", chat.character.prompt_role(chat)
  end

  test "prompt_role returns other for other ai characters" do
    chat = chats(:anton_with_zoe)
    other_ai = Character.create!(name: "Helper AI", ai: true, third_party: false)

    assert_equal "other", other_ai.prompt_role(chat)
  end

  test "prompt_role returns other for non-ai characters" do
    chat = chats(:anton_with_zoe)
    known_human = Character.create!(name: "Maria", ai: false, third_party: false)

    assert_equal "other", known_human.prompt_role(chat)
  end

  test "prompt_relation returns unfamiliar without aggregate bands" do
    chat = chats(:anton_with_zoe)
    known_human = Character.create!(name: "Maria", ai: false, third_party: false)

    assert_equal "unfamiliar", known_human.prompt_relation(partner: chat.partner)
  end

  test "prompt_relation returns familiar when aggregate bands exist" do
    chat = chats(:anton_with_zoe)
    known_human = Character.create!(name: "Maria", ai: false, third_party: false)

    FactAggregate.create!(
      character: known_human,
      partner: chat.partner,
      topic: topics(:work),
      kind: "m0_3",
      anchor_month: Date.new(2026, 4, 1),
      body: "Familiar profile",
      facts_count: 1,
      source_updated_at: Time.zone.now
    )

    assert_equal "familiar", known_human.prompt_relation(partner: chat.partner)
  end
end
