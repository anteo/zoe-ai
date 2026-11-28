class AddConfigToAgents < ActiveRecord::Migration[8.1]
  def change
    add_column :agents, :config, :jsonb, default: {}, null: false
  end
end
