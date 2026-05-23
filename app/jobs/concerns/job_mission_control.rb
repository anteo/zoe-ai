module JobMissionControl
  extend ActiveSupport::Concern

  def execution
    @execution ||= SolidQueue::ClaimedExecution.find_by(job_id: provider_job_id)
  end

  class_methods do
    def find_executions(model, execution_class)
      execution_class
        .joins(:job)
        .includes(:job)
        .where(job: { class_name: name })
        .filter_map do |execution|

        job = execution.job
        arguments = job.arguments["arguments"]
        next unless arguments.size > 0

        gid = GlobalID.parse(arguments[0]["_aj_globalid"])
        next unless gid.model_class == model.class && gid.model_id.to_i == model.id

        execution
      rescue ActiveJob::DeserializationError
        nil
      end
    end

    def get_running_executions(model)
      find_executions(model, SolidQueue::ClaimedExecution)
    end

    def running_for?(model)
      get_running_executions(model).any? { !it.cancelled? }
    end

    def get_scheduled_executions(model)
      find_executions(model, SolidQueue::ScheduledExecution)
    end

    def get_ready_executions(model)
      find_executions(model, SolidQueue::ReadyExecution)
    end

    def get_blocked_executions(model)
      find_executions(model, SolidQueue::BlockedExecution)
    end

    def get_queued_executions(model)
      (get_ready_executions(model) + get_scheduled_executions(model) + get_blocked_executions(model))
        .uniq { it.job_id }
    end

    def cancel(model)
      get_running_executions(model).each do |execution|
        execution.update(cancelled: true) unless execution.cancelled?
      end

      get_queued_executions(model).each { it.job.discard }
    end
  end
end
