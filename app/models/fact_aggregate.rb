class FactAggregate < ApplicationRecord
  belongs_to :character
  belongs_to :partner, class_name: "Character"
  belongs_to :topic
  belongs_to :parent, class_name: "FactAggregate", optional: true
  has_many :children, class_name: "FactAggregate", foreign_key: :parent_id, dependent: :nullify

  enum :summary_status, {
    pending: "pending",
    in_progress: "in_progress",
    done: "done",
    failed: "failed"
  }, validate: true

  validates :kind, presence: true
  validates :slot_key, presence: true, uniqueness: true
  validates :body, presence: true
  validates :facts_count, numericality: { greater_than_or_equal_to: 0 }

  before_validation :set_slot_key

  scope :months, -> { where(kind: "month") }
  scope :bands, -> { where.not(kind: "month") }

  def self.mark_months_stale!(slot_keys)
    return if slot_keys.empty?

    months.where(slot_key: slot_keys, stale: false)
      .update_all(stale: true, updated_at: Time.current)
  end

  def self.slot_key_for(character_id:, partner_id:, topic_id:, kind:, anchor_month:)
    [
      "character", character_id,
      "partner", partner_id,
      "topic", topic_id,
      kind,
      anchor_month.to_date.beginning_of_month.iso8601
    ].join(":")
  end

  def self.latest_anchor_month
    maximum(:anchor_month)
  end

  def band_kind_for(anchor_month)
    return unless bucket_month

    months_ago = (anchor_month.year * 12 + anchor_month.month) - (bucket_month.year * 12 + bucket_month.month)

    case months_ago
    when 0..2
      "m0_3"
    when 3..5
      "m3_6"
    when 6..11
      "m6_12"
    when 12..23
      "m12_24"
    else
      "year_#{bucket_month.year}"
    end
  end

  def month?
    kind == "month"
  end

  def band?
    !month?
  end

  def period(anchor_month = self.anchor_month)
    anchor_month = anchor_month.to_date.beginning_of_month

    case kind
    when "month"
      self.anchor_month..self.anchor_month
    when "m0_3"
      (anchor_month << 2)..anchor_month
    when "m3_6"
      (anchor_month << 5)..(anchor_month << 3)
    when "m6_12"
      (anchor_month << 11)..(anchor_month << 6)
    when "m12_24"
      (anchor_month << 23)..(anchor_month << 12)
    when /\Ayear_(\d{4})\z/
      Date.new(Regexp.last_match(1).to_i, 1, 1)..Date.new(Regexp.last_match(1).to_i, 12, 1)
    end
  end

  def dirty?
    stale? || changed?
  end

  def source_records
    month? ? source_facts : children.order(:anchor_month)
  end

  def bucket_month
    anchor_month if month?
  end

  private

  def source_facts
    character.facts_to_consider
             .where(partner_id: partner_id)
             .persistent
             .where(topic_id: topic_id, month: anchor_month)
             .includes(:author, :topic)
             .order(:mentioned_at, :id)
  end

  def set_slot_key
    return if character_id.blank? || topic_id.blank? || kind.blank? || anchor_month.blank?

    self.slot_key = self.class.slot_key_for(
      character_id: character_id,
      partner_id: partner_id,
      topic_id: topic_id,
      kind: kind,
      anchor_month: anchor_month
    )
  end
end
