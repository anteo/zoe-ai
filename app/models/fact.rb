class Fact < ApplicationRecord
  belongs_to :character
  belongs_to :partner, class_name: "Character"
  belongs_to :author, class_name: "Character"
  belongs_to :message
  belongs_to :chat
  belongs_to :topic

  before_save :set_month
  after_commit :mark_month_aggregates_stale, on: [ :create, :update, :destroy ]

  scope :persistent, ->(persistent = true) { where(persistent:) }
  scope :present, -> { where(time: "present") }
  scope :timed, -> { where(time: %w[past future]) }
  scope :by_kind, ->(kind) { where(kind:) }
  scope :excluding_kind, ->(kind) { where.not(kind:) }

  validates :content, :time, presence: true

  def to_s
    "#{"#{topic}: " if topic}#{content}"
  end

  def to_description
    author_id != character_id ? "According to #{author.name}: #{content}" : content
  end

  def prompt_source
    author_id == character_id ? "self" : author.name
  end

  def prompt_date
    if date_from && date_to && date_from != date_to
      "#{date_from.iso8601}/#{date_to.iso8601}"
    elsif date_from
      date_from.iso8601
    elsif date_to
      date_to.iso8601
    else
      mentioned_date&.iso8601
    end
  end

  def time_present?
    time == "present"
  end

  def time_past?
    time == "past"
  end

  def time_future?
    time == "future"
  end

  def mentioned_date
    mentioned_at&.to_date
  end

  def period
    if date_from || date_to
      (date_from..date_to)
    elsif time_present?
      (mentioned_date..mentioned_date)
    elsif time_past?
      (..mentioned_date)
    elsif time_future?
      (mentioned_date..)
    end
  end

  def to_h
    {
      character_id: character_id.to_s,
      character_name: character.name,
      partner_id: partner_id,
      fact: content,
      kind:,
      time:,
      importance:,
      persistent:,
      date_from:,
      date_to:,
      topic_id:,
      topic_name: topic&.name
    }
  end

  private

  def mark_month_aggregates_stale
    FactAggregate.mark_months_stale!(affected_month_aggregate_slot_keys)
  end

  def affected_month_aggregate_slot_keys
    [ current_persistent_month_slot_key, previous_persistent_month_slot_key ].compact.uniq
  end

  def current_persistent_month_slot_key
    month_aggregate_slot_key_for(
      character_id: character_id,
      partner_id: partner_id,
      topic_id: topic_id,
      month: month,
      persistent: persistent?
    )
  end

  def previous_persistent_month_slot_key
    return if destroyed?

    month_aggregate_slot_key_for(
      character_id: attribute_before_last_save("character_id"),
      partner_id: attribute_before_last_save("partner_id"),
      topic_id: attribute_before_last_save("topic_id"),
      month: attribute_before_last_save("month"),
      persistent: attribute_before_last_save("persistent")
    )
  end

  def month_aggregate_slot_key_for(character_id:, partner_id:, topic_id:, month:, persistent:)
    return unless persistent
    return if character_id.blank? || partner_id.blank? || topic_id.blank? || month.blank?

    FactAggregate.slot_key_for(
      character_id:,
      partner_id:,
      topic_id:,
      kind: "month",
      anchor_month: month
    )
  end

  def set_month
    self.month = mentioned_at&.to_date&.beginning_of_month
  end
end
