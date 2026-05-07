class AddBioToCharacters < ActiveRecord::Migration[8.0]
  def change
    add_column :characters, :bio, :string, null: false, default: ""
  end
end
