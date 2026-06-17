class AddTTSEnabledToMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :messages, :tts_enabled, :boolean, default: false, null: false
  end
end
