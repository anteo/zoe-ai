class CreateUsersAndRefactorChats < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email
      t.string :first_name
      t.string :last_name
      t.timestamps
    end

    add_reference :characters, :user, foreign_key: true

    remove_column :characters, :email, :string

    rename_column :chats, :user_id, :character_id
  end
end
