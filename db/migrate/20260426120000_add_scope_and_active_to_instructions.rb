class AddScopeAndActiveToInstructions < ActiveRecord::Migration[8.1]
  def change
    change_column_null :instructions, :character_id, true

    add_column :instructions, :scope, :string, null: false, default: "character"
    add_column :instructions, :active, :boolean, null: false, default: true

    add_index :instructions, [ :scope, :active ], name: "index_instructions_on_scope_and_active"
  end
end
