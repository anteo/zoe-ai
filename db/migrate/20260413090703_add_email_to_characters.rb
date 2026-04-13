class AddEmailToCharacters < ActiveRecord::Migration[8.0]
  def change
    add_column :characters, :email, :string
  end
end
