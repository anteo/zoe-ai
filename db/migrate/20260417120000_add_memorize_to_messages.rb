class AddMemorizeToMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :messages, :memorize, :boolean, default: true, null: false
  end
end
