class AddAuthorToCharacters < ActiveRecord::Migration[8.1]
  def up
    add_reference :characters, :author, foreign_key: { to_table: :users }

    execute <<~SQL
      UPDATE characters
      SET author_id = character_users.user_id
      FROM (
        SELECT character_id, MIN(user_id) AS user_id
        FROM characters_users
        GROUP BY character_id
      ) AS character_users
      WHERE characters.id = character_users.character_id
        AND characters.author_id IS NULL
    SQL
  end

  def down
    remove_reference :characters, :author, foreign_key: { to_table: :users }
  end
end
