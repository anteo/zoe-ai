class CreateAgentConversations < ActiveRecord::Migration[8.1]
  def up
    create_table :agent_conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :character, null: false, foreign_key: true
      t.references :partner, null: false, foreign_key: { to_table: :characters }
      t.references :agent, foreign_key: { on_delete: :nullify }
      t.string :agent_name, null: false
      t.boolean :local_workspace, null: false, default: false
      t.string :workspace_runner_id
      t.string :workspace_conversation_id
      t.timestamps

      t.index [ :user_id, :character_id, :partner_id ]
    end

    add_reference :agent_runs, :agent_conversation, foreign_key: true
    execute <<~SQL
      INSERT INTO agent_conversations
        (id, user_id, character_id, partner_id, agent_id, agent_name, local_workspace, created_at, updated_at)
      SELECT
        agent_runs.id, chats.user_id, chats.character_id, chats.partner_id, agent_runs.agent_id,
        agent_runs.agent_name, agent_runs.local_workspace, agent_runs.created_at, agent_runs.updated_at
      FROM agent_runs
      JOIN chats ON chats.id = agent_runs.chat_id;

      UPDATE agent_runs SET agent_conversation_id = id;
    SQL
    reset_pk_sequence!(:agent_conversations)
    change_column_null :agent_runs, :agent_conversation_id, false
    add_index :agent_runs, :agent_conversation_id, unique: true, where: "status = 'running'",
              name: "index_agent_runs_on_running_conversation"
  end

  def down
    remove_reference :agent_runs, :agent_conversation, foreign_key: true
    drop_table :agent_conversations
  end
end
