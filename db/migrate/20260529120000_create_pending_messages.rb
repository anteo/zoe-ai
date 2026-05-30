class CreatePendingMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :pending_messages do |t|
      t.references :author, null: false, foreign_key: { to_table: :characters }
      t.references :character, null: false, foreign_key: true
      t.text :content, null: false, default: ""

      t.timestamps
    end

    add_index :pending_messages, [ :character_id, :author_id, :created_at ],
              name: "index_pending_messages_on_delivery_lookup"
  end
end
