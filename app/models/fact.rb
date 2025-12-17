class Fact < ApplicationRecord
  belongs_to :character
  belongs_to :author, class_name: "Character"
  belongs_to :message
  belongs_to :chat
  belongs_to :topic

  before_validation :set_author_default
  after_save :update_character_description, if: :persistent?

  scope :persistent, ->(persistent = true) { where(persistent:) }
  scope :present, -> { where(time: "present") }
  scope :timed, -> { where(time: %w[past future]) }
  scope :by_kind, ->(kind) { where(kind:) }
  scope :excluding_kind, ->(kind) { where.not(kind:) }

  validates :content, :time, presence: true

  def to_s
    "#{"#{topic}: " if topic}#{content}"
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
      character: character.name,
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

  def set_author_default
    self.author ||= character
  end

  def update_character_description
    character.update_column :description_up_to_date, false
  end
end
