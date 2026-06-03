class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  scope :created_yesterday, -> { where(created_at: Date.yesterday.all_day) }

  def self.[](attribute)
    arel_table[attribute]
  end

  def system_logger
    @system_logger ||= SystemLogger.instance.with_payload(
      source: "active_record",
      model: self.class.name,
      id:
    )
  end

  def logger
    @logger ||= ActiveSupport::BroadcastLogger.new(system_logger, super)
  end
end
