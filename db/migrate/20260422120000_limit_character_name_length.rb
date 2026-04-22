class LimitCharacterNameLength < ActiveRecord::Migration[8.0]
  def change
    change_column :characters, :name, :string, limit: 50, null: false
  end
end
