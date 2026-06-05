class AddPostponedToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :postponed, :boolean, default: false, null: false
    add_reference :messages, :initiator, foreign_key: { to_table: :characters }
    add_index :messages, :postponed
  end
end
