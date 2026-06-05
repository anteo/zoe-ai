class AddPartnerToPendingMessages < ActiveRecord::Migration[8.1]
  def up
    add_reference :pending_messages, :partner, foreign_key: { to_table: :characters }

    execute <<~SQL.squish
      UPDATE pending_messages
      SET partner_id = author_id
      WHERE partner_id IS NULL
    SQL

    execute <<~SQL.squish
      UPDATE pending_messages
      SET author_id = messages.character_id
      FROM messages
      WHERE pending_messages.source_message_id = messages.id
        AND pending_messages.author_id = pending_messages.partner_id
    SQL

    change_column_null :pending_messages, :partner_id, false

    remove_index :pending_messages, name: "index_pending_messages_on_delivery_lookup"
    add_index :pending_messages,
              [ :user_id, :character_id, :partner_id, :created_at ],
              name: "index_pending_messages_on_delivery_lookup"
  end

  def down
    remove_index :pending_messages, name: "index_pending_messages_on_delivery_lookup"
    add_index :pending_messages,
              [ :user_id, :character_id, :author_id, :created_at ],
              name: "index_pending_messages_on_delivery_lookup"

    execute <<~SQL.squish
      UPDATE pending_messages
      SET author_id = partner_id
      WHERE partner_id IS NOT NULL
    SQL

    remove_reference :pending_messages, :partner, foreign_key: { to_table: :characters }
  end
end
