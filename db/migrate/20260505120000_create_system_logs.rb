class CreateSystemLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :system_logs do |t|
      t.string :severity, null: false
      t.text :message, null: false
      t.string :source, null: false
      t.datetime :logged_at, null: false

      t.timestamps
    end

    add_index :system_logs, [ :severity, :logged_at, :id ], name: "index_system_logs_on_severity_and_logged_at"
    add_index :system_logs, [ :logged_at, :id ], name: "index_system_logs_on_logged_at"
  end
end
