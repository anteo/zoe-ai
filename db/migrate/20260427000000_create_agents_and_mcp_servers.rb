class CreateAgentsAndMCPServers < ActiveRecord::Migration[8.1]
  def change
    create_table :agents do |t|
      t.string  :key,             null: false
      t.string  :name,            null: false
      t.boolean :builtin,         null: false, default: false
      t.boolean :active,          null: false, default: true
      t.references :model,        foreign_key: true
      t.text    :instructions
      t.float   :temperature
      t.string  :thinking_effort
      t.integer :thinking_budget
      t.timestamps

      t.index :key, unique: true
    end

    create_table :mcp_servers do |t|
      t.string  :key,             null: false
      t.string  :name,            null: false
      t.string  :transport_type,  null: false
      t.jsonb   :config,          null: false, default: {}
      t.boolean :active,          null: false, default: true
      t.text    :last_error
      t.timestamps

      t.index :key, unique: true
    end

    create_table :agents_mcp_servers, id: false do |t|
      t.references :agent,      null: false, foreign_key: true
      t.references :mcp_server, null: false, foreign_key: true

      t.index [:agent_id, :mcp_server_id], unique: true
    end
  end
end
