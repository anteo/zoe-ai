class AddDefaultToCharacters < ActiveRecord::Migration[8.0]
  def up
    add_column :characters, :is_default, :boolean, default: false, null: false
    add_index :characters, :is_default
    add_index :characters, :is_default, unique: true,
              where: "ai = TRUE AND is_default = TRUE",
              name: "index_characters_on_single_default_ai"
  end

  def down
    remove_index :characters, name: "index_characters_on_single_default_ai"
    remove_index :characters, :is_default
    remove_column :characters, :is_default
  end
end
