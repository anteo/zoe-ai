class Topic < ApplicationRecord
  has_many :fact_aggregates, dependent: :delete_all

  def to_s
    name
  end
end
