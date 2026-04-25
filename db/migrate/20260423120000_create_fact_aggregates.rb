class CreateFactAggregates < ActiveRecord::Migration[8.0]
  def change
    create_table :fact_aggregates do |t|
      t.references :character, null: false, foreign_key: true
      t.references :topic, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :fact_aggregates }
      t.string :kind, null: false
      t.string :slot_key, null: false
      t.date :anchor_month
      t.integer :facts_count, null: false, default: 0
      t.datetime :source_updated_at
      t.boolean :stale, null: false, default: false
      t.text :body, null: false, default: ""

      t.timestamps
    end

    add_index :fact_aggregates, :slot_key, unique: true, name: "idx_fact_aggregates_unique_slot"
    add_index :fact_aggregates, [ :character_id, :kind, :anchor_month ], name: "idx_fact_aggregates_band_lookup"
  end
end
