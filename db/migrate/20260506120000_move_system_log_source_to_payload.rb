class MoveSystemLogSourceToPayload < ActiveRecord::Migration[8.1]
  def change
    add_column :system_logs, :payload, :jsonb, default: {}, null: false
    remove_column :system_logs, :source, :string
  end
end
