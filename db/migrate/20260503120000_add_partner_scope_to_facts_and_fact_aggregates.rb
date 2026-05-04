class AddPartnerScopeToFactsAndFactAggregates < ActiveRecord::Migration[8.1]
  def up
    add_reference :facts, :partner, foreign_key: { to_table: :characters }, index: true, null: true unless column_exists?(:facts, :partner_id)
    add_reference :fact_aggregates, :partner, foreign_key: { to_table: :characters }, index: true, null: true unless column_exists?(:fact_aggregates, :partner_id)

    execute <<~SQL.squish
      UPDATE facts
      SET partner_id = chats.partner_id
      FROM chats
      WHERE facts.chat_id = chats.id
        AND facts.partner_id IS NULL
    SQL

    default_partner_id = select_value(<<~SQL.squish)
      SELECT id
      FROM characters
      WHERE ai = TRUE AND is_default = TRUE
      ORDER BY id ASC
      LIMIT 1
    SQL

    raise ActiveRecord::MigrationError, "Default AI character not found for partner_id backfill" if default_partner_id.blank?

    execute <<~SQL.squish
      UPDATE facts
      SET partner_id = #{Integer(default_partner_id)}
      WHERE partner_id IS NULL
    SQL

    execute <<~SQL.squish
      UPDATE fact_aggregates
      SET partner_id = #{Integer(default_partner_id)}
      WHERE partner_id IS NULL
    SQL

    change_column_null :facts, :partner_id, false
    change_column_null :fact_aggregates, :partner_id, false

    remove_index :facts, name: "idx_facts_month_lookup" if index_exists?(:facts, [ :character_id, :persistent, :topic_id, :month ], name: "idx_facts_month_lookup")
    add_index :facts, [ :character_id, :partner_id, :persistent, :topic_id, :month ], name: "idx_facts_month_lookup"

    remove_index :fact_aggregates, name: "idx_fact_aggregates_band_lookup" if index_exists?(:fact_aggregates, [ :character_id, :kind, :anchor_month ], name: "idx_fact_aggregates_band_lookup")
    add_index :fact_aggregates, [ :character_id, :partner_id, :kind, :anchor_month ], name: "idx_fact_aggregates_band_lookup"

    execute <<~SQL.squish
      UPDATE fact_aggregates
      SET slot_key = CONCAT(
        'character:', character_id,
        ':partner:', partner_id,
        ':topic:', topic_id,
        ':', kind,
        ':', TO_CHAR(anchor_month, 'YYYY-MM-DD')
      )
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE fact_aggregates
      SET slot_key = CONCAT(
        'character:', character_id,
        ':topic:', topic_id,
        ':', kind,
        ':', TO_CHAR(anchor_month, 'YYYY-MM-DD')
      )
    SQL

    remove_index :fact_aggregates, name: "idx_fact_aggregates_band_lookup" if index_exists?(:fact_aggregates, [ :character_id, :partner_id, :kind, :anchor_month ], name: "idx_fact_aggregates_band_lookup")
    add_index :fact_aggregates, [ :character_id, :kind, :anchor_month ], name: "idx_fact_aggregates_band_lookup"

    remove_index :facts, name: "idx_facts_month_lookup" if index_exists?(:facts, [ :character_id, :partner_id, :persistent, :topic_id, :month ], name: "idx_facts_month_lookup")
    add_index :facts, [ :character_id, :persistent, :topic_id, :month ], name: "idx_facts_month_lookup"

    remove_reference :fact_aggregates, :partner, foreign_key: { to_table: :characters }, index: true if column_exists?(:fact_aggregates, :partner_id)
    remove_reference :facts, :partner, foreign_key: { to_table: :characters }, index: true if column_exists?(:facts, :partner_id)
  end
end
