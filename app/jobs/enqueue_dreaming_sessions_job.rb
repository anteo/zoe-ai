class EnqueueDreamingSessionsJob < ApplicationJob
  limits_concurrency to: 1,
                     key: -> { "enqueue_dreaming_sessions_#{Date.current}" }

  def perform
    eligible_pairs.each do |user_id, character_id, partner_id|
      RunDreamingSessionJob.perform_later(user_id, character_id, partner_id)
    end
  end

  private

  def eligible_pairs
    (pairs_with_recent_real_chats + pairs_with_daily_dreaming).uniq
  end

  def base_pairs_scope
    Chat.dreaming(false)
        .closed
        .joins(:user)
        .where(Chat[:character_id].eq(User[:main_character_id]))
        .where(character_id: Character.human.select(:id))
        .where(partner_id: Character.ai.dreaming_enabled.select(:id))
  end

  def pairs_with_recent_real_chats
    base_pairs_scope
      .created_yesterday
      .distinct
      .pluck(:user_id, :character_id, :partner_id)
  end

  def pairs_with_daily_dreaming
    base_pairs_scope
      .where(partner_id: Character.ai.dreaming_enabled.daily_dreaming_enabled.select(:id))
      .distinct
      .pluck(:user_id, :character_id, :partner_id)
  end
end
