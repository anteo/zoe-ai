class AddStaleToModels < ActiveRecord::Migration[8.0]
  def change
    add_column :models, :stale, :boolean, null: false, default: false
    add_index :models, :stale
  end
end
