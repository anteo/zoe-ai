class AddThirdPartyToCharacters < ActiveRecord::Migration[8.0]
  def change
    add_column :characters, :third_party, :boolean, default: false, null: false
  end
end
