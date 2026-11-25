class CreateAgentRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_runs do |t|
      t.references :chat, null: false, foreign_key: true
      t.references :agent, foreign_key: { on_delete: :nullify }
      t.references :trigger_message, foreign_key: { to_table: :messages, on_delete: :nullify }
      t.string :agent_name, null: false
      t.string :status, null: false, default: "running"
      t.text :task, null: false
      t.boolean :local_workspace, null: false, default: false
      t.string :workspace_run_id
      t.string :workspace_status
      t.integer :workspace_sequence, null: false, default: 0
      t.text :result
      t.text :error
      t.datetime :finished_at
      t.timestamps
    end

    create_table :agent_run_events do |t|
      t.references :agent_run, null: false, foreign_key: true
      t.string :kind, null: false
      t.text :message
      t.jsonb :data, null: false, default: {}
      t.datetime :created_at, null: false
    end
  end
end
