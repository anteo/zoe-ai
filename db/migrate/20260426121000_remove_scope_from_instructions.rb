class RemoveScopeFromInstructions < ActiveRecord::Migration[8.1]
  def change
    remove_index :instructions, name: "index_instructions_on_scope_and_active"
    remove_column :instructions, :scope, :string, null: false, default: "character"

    add_index :instructions, [ :character_id, :active ], name: "index_instructions_on_character_id_and_active"
  end
end
