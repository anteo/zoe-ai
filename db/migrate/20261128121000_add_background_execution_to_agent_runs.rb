class AddBackgroundExecutionToAgentRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :agent_runs, :background_job_id, :string
    add_column :agent_runs, :reported_at, :datetime
  end
end
