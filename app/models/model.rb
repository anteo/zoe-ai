class Model < ApplicationRecord
  acts_as_model

  scope :available, -> { where(stale: false) }

  class << self
    def save_to_database
      transaction do
        update_all(stale: true)
        super
      end
    end

    private

    def from_llm_attributes(model_info)
      super.merge(stale: false)
    end
  end
end
