class MakeAgentKeyNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :agents, :key, true
  end
end
