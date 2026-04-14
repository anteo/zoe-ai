class AddClosedToChats < ActiveRecord::Migration[8.0]
  def change
    add_column :chats, :closed, :boolean, default: false, null: false
  end
end
