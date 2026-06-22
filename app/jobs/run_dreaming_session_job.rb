class RunDreamingSessionJob < ApplicationJob
  limits_concurrency to: 1,
                     key: ->(user_id, character_id, partner_id) { "run_dreaming_session_#{user_id}_#{character_id}_#{partner_id}" },
                     on_conflict: :discard

  def perform(user_id, character_id, partner_id)
    user = User.find_by(id: user_id)
    character = Character.find_by(id: character_id)
    partner = Character.find_by(id: partner_id)

    return unless user && character && partner
    return unless character.human?
    return unless partner.ai? && partner.dreaming_enabled?

    dream_chat = AI::Agents::Dreaming.create!(character:, partner:, user:, dream: true)
    dream_chat.deliver_pending_messages!
    dream_chat.complete
    summary = dream_chat.latest_assistant_message_content
    dream_chat.update!(closed: true, closed_at: Time.current, summary:)

    # Do not extract facts from dreaming sessions for now -> they mostly duplicate conversation facts
    # ExtractFactsJob.perform_later(dream_chat)
  end
end
