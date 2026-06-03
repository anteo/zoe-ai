class AddDreamingSupport < ActiveRecord::Migration[8.0]
  def change
    add_column :chats, :closed_at, :datetime
    add_column :chats, :dream, :boolean, default: false, null: false
    add_index :chats, :dream
    add_index :chats, :closed_at

    add_column :characters, :dreaming_enabled, :boolean, default: false, null: false
    add_column :characters, :daily_dreaming_enabled, :boolean, default: false, null: false

    add_column :instructions, :dream, :boolean, default: false, null: false
    add_index :instructions, :dream
    add_index :instructions, [ :character_id, :dream, :active ], name: "index_instructions_on_character_id_and_dream_and_active"

    add_reference :pending_messages, :source_message, foreign_key: { to_table: :messages }
  end
end
