class AddRespondJobToAgentRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :agent_runs, :respond_job_id, :string
    add_column :agent_runs, :respond_job_execution_id, :bigint
  end
end
