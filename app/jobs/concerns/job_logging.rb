module JobLogging
  extend ActiveSupport::Concern

  included do
    around_perform :with_job_logging
  end

  def logger
    SystemLogger.instance.with_payload(
      source: "active_job",
      job_class: self.class.name,
      job_id:,
      provider_job_id:
    )
  end

  private

  def with_job_logging
    logger.info("#{self.class.name} starting...")
    yield
    logger.info("#{self.class.name} finished.")
  rescue StandardError => e
    logger.error("#{self.class.name} failed: #{e.message}",
                 error_class: e.class.name,
                 error_message: e.message,
                 error_backtrace: e.backtrace.first(10))
    raise
  end
end
