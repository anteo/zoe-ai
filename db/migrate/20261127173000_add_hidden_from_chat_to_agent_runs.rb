class AddHiddenFromChatToAgentRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :agent_runs, :hidden_from_chat, :boolean, default: false, null: false
  end
end
