class AddUserReferenceToChats < ActiveRecord::Migration[7.0]
  def change
    add_reference :chats, :user, foreign_key: true
  end
end
