class AddMonthToFacts < ActiveRecord::Migration[8.0]
  def up
    add_column :facts, :month, :date

    execute <<~SQL
      UPDATE facts
      SET month = DATE_TRUNC('month', mentioned_at)::date
      WHERE mentioned_at IS NOT NULL
    SQL

    add_index :facts, [ :character_id, :persistent, :topic_id, :month ], name: "idx_facts_month_lookup"
  end

  def down
    remove_index :facts, name: "idx_facts_month_lookup"
    remove_column :facts, :month
  end
end
