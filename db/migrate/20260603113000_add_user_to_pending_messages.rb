class AddUserToPendingMessages < ActiveRecord::Migration[8.0]
  def up
    add_reference :pending_messages, :user, foreign_key: true

    execute <<~SQL.squish
      UPDATE pending_messages
      SET user_id = chats.user_id
      FROM messages
      INNER JOIN chats ON chats.id = messages.chat_id
      WHERE pending_messages.source_message_id = messages.id
        AND pending_messages.user_id IS NULL
    SQL

    remove_index :pending_messages, name: "index_pending_messages_on_delivery_lookup"
    add_index :pending_messages,
              [ :user_id, :character_id, :author_id, :created_at ],
              name: "index_pending_messages_on_delivery_lookup"
  end

  def down
    remove_index :pending_messages, name: "index_pending_messages_on_delivery_lookup"
    add_index :pending_messages,
              [ :character_id, :author_id, :created_at ],
              name: "index_pending_messages_on_delivery_lookup"

    remove_reference :pending_messages, :user, foreign_key: true
  end
end
