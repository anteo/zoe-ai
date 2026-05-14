class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

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
