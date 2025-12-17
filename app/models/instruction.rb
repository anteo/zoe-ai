class Instruction < ApplicationRecord
  belongs_to :character

  def to_s
    content
  end
end
