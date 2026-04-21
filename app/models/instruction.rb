class Instruction < ApplicationRecord
  belongs_to :character

  normalizes :content, with: ->(value) { value.to_s.strip.presence }
  validates :content, presence: true

  def to_s
    content
  end
end
