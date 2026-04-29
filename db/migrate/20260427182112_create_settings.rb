class CreateSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :settings do |t|
      t.string :scope, null: false
      t.string :key,   null: false
      t.string :value
      t.timestamps
    end

    add_index :settings, [ :scope, :key ], unique: true
  end
end
