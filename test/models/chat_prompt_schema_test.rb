require "test_helper"

class ChatPromptSchemaTest < ActiveSupport::TestCase
  fixtures :characters, :users, :chats, :characters_users, :topics

  test "described_identities returns only non-primary characters with descriptions" do
    chat = chats(:anton_with_zoe)
    known = Character.create!(name: "Maria", ai: false, third_party: false)
    chat.user.characters << known
    FactAggregate.create!(
      character: known,
      partner: chat.partner,
      topic: topics(:work),
      kind: "m0_3",
      anchor_month: Date.new(2026, 4, 1),
      body: "Known profile",
      summary: "Known profile",
      facts_count: 1,
      source_updated_at: Time.zone.now
    )

    identities = chat.described_identities(mode: :xml)

    assert_equal 1, identities.size
    assert_equal known, identities.first[0]
    assert_includes identities.first[1], "Known profile"
  end

  test "zoe instructions include relation metadata and identity entries without known_characters block" do
    chat = chats(:anton_with_zoe)
    known = Character.create!(name: "Maria", ai: false, third_party: false)
    chat.user.characters << known

    create_identity_aggregate!(chat.partner, chat, "Zoe profile")
    create_identity_aggregate!(chat.character, chat, "Anton profile")
    create_identity_aggregate!(known, chat, "Maria profile")

    output = ERB.new(
      File.read(Rails.root.join("app/prompts/ai/agents/zoe/instructions.txt.erb")),
      trim_mode: "-"
    ).result_with_hash(
      chat:,
      helpers: AI::PromptController.new.helpers,
      interlocutor_description: chat.described_character(chat.character, mode: :xml)
    )

    assert_includes output, "relation=\""
    assert_includes output, "<identity character_id=\"#{known.id}\" name=\"Maria\" role=\"other\" type=\"human\""
    assert_includes output, "<identity character_id=\"#{chat.partner.id}\" name=\"Zoe\" role=\"you\" type=\"ai\""
    assert_not_includes output, "<known_characters>"
  end

  private

  def create_identity_aggregate!(character, chat, summary)
    FactAggregate.create!(
      character:,
      partner: chat.partner,
      topic: topics(:work),
      kind: "m0_3",
      anchor_month: Date.new(2026, 4, 1),
      body: summary,
      summary:,
      facts_count: 1,
      source_updated_at: Time.zone.now
    )
  end

end
