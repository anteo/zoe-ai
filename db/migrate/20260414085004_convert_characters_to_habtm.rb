class ConvertCharactersToHabtm < ActiveRecord::Migration[8.0]
  def up
    create_table :characters_users, id: false do |t|
      t.bigint :character_id, null: false
      t.bigint :user_id, null: false
    end
    add_index :characters_users, [ :character_id, :user_id ], unique: true
    add_index :characters_users, :user_id

    add_column :users, :main_character_id, :bigint
    add_index :users, :main_character_id
    add_foreign_key :users, :characters, column: :main_character_id

    # Migrate existing user_id data into the join table
    execute <<~SQL
      INSERT INTO characters_users (character_id, user_id)
      SELECT id, user_id FROM characters WHERE user_id IS NOT NULL
    SQL

    # Set each user's main_character to their first character (by name)
    execute <<~SQL
      UPDATE users
      SET main_character_id = (
        SELECT id FROM characters
        WHERE characters.user_id = users.id
        ORDER BY name
        LIMIT 1
      )
      WHERE EXISTS (
        SELECT 1 FROM characters WHERE characters.user_id = users.id
      )
    SQL

    remove_foreign_key :characters, :users
    remove_column :characters, :user_id
  end

  def down
    add_column :characters, :user_id, :bigint
    add_index :characters, :user_id
    add_foreign_key :characters, :users

    # Restore user_id from join table (pick the first user per character)
    execute <<~SQL
      UPDATE characters
      SET user_id = (
        SELECT user_id FROM characters_users
        WHERE characters_users.character_id = characters.id
        ORDER BY user_id
        LIMIT 1
      )
    SQL

    remove_foreign_key :users, column: :main_character_id
    remove_column :users, :main_character_id
    drop_table :characters_users
  end
end
