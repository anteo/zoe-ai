class AddHistoryMessageMetadataToChats < ActiveRecord::Migration[8.1]
  def change
    change_table :chats, bulk: true do |t|
      t.references :first_visible_message, foreign_key: { to_table: :messages, on_delete: :nullify }
      t.references :last_visible_message, foreign_key: { to_table: :messages, on_delete: :nullify }
      t.datetime :first_visible_message_at
      t.datetime :last_visible_message_at
    end

    add_index :chats, :first_visible_message_at
    add_index :chats, :last_visible_message_at
  end
end
