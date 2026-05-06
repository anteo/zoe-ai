class ConfirmExistingUsers < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE users
      SET confirmed_at = COALESCE(confirmed_at, created_at, NOW())
      WHERE confirmed_at IS NULL
    SQL
  end

  def down
    # no-op: irreversible data change
  end
end
