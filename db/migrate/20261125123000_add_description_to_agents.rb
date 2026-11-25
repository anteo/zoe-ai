class AddDescriptionToAgents < ActiveRecord::Migration[8.1]
  def up
    add_column :agents, :description, :text
    execute <<~SQL
      UPDATE agents
      SET builtin = FALSE,
          description = 'Lists local projects, searches their files, and reads file contents by workspace-relative path.'
      WHERE key = 'workspace_assistant'
    SQL
  end

  def down
    execute "UPDATE agents SET builtin = TRUE WHERE key = 'workspace_assistant'"
    remove_column :agents, :description
  end
end
