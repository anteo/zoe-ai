module MissionControl
  extend ActiveSupport::Concern

  def execution
    @execution ||= SolidQueue::ClaimedExecution.find_by(job_id: provider_job_id)
  end

  class_methods do
    def find_execution(model, execution_class)
      execution_class
        .joins(:job)
        .includes(:job)
        .where(job: { class_name: name })
        .find_each do |execution|

        job = execution.job
        arguments = job.arguments["arguments"]
        next unless arguments.size > 0

        gid = GlobalID.parse(arguments[0]["_aj_globalid"])
        next unless gid.model_class == model.class && gid.model_id.to_i == model.id

        return execution
      rescue ActiveJob::DeserializationError
        nil
      end
      nil
    end

    def get_running_execution(model)
      find_execution(model, SolidQueue::ClaimedExecution)
    end

    def get_scheduled_execution(model)
      find_execution(model, SolidQueue::ScheduledExecution)
    end

    def get_ready_execution(model)
      find_execution(model, SolidQueue::ReadyExecution)
    end

    def get_execution(model)
      get_ready_execution(model) || get_scheduled_execution(model) || get_running_execution(model)
    end

    def cancel(model)
      if (ex = get_running_execution(model))
        ex.update cancelled: true
      elsif (ex = get_scheduled_execution(model))
        ex.job.discard
      end
    end
  end
end