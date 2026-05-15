class Topic < ApplicationRecord
  has_many :fact_aggregates, dependent: :delete_all

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name]
  end

  def to_s
    name
  end
end
