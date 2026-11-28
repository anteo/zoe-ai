class AgentRunJob < ApplicationJob
  POLL_INTERVAL = 2.seconds

  # The queue shares the application database. Store the execution and its job together.
  self.enqueue_after_transaction_commit = false

  def perform(run_id, project: nil)
    run = AgentRun.running.find_by(id: run_id, background_job_id: job_id)
    return unless run

    AI::AgentDelegation.new(run.chat).advance(run, project:)

    run.with_lock do
      next unless run.running? && run.background_job_id == job_id

      run.enqueue_background!(project:, wait: POLL_INTERVAL)
    end
  end
end
