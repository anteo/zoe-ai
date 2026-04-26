class Instruction < ApplicationRecord
  belongs_to :character, optional: true

  normalizes :content, with: ->(value) { value.to_s.strip.presence }

  validates :content, presence: true

  scope :active, -> { where(active: true) }
  scope :global, -> { where(character_id: nil) }
  scope :for_character, ->(character) { where(character:) }
  scope :ordered, -> { order(:created_at, :id) }

  def to_s
    content
  end
end
