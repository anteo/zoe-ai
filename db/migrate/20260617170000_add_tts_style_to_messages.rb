class AddTTSStyleToMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :messages, :tts_style, :string
  end
end
