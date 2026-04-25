class AddSummaryFieldsToFactAggregates < ActiveRecord::Migration[8.0]
  def change
    add_column :fact_aggregates, :summary, :text
    add_column :fact_aggregates, :summary_status, :string, null: false, default: "pending"
    add_column :fact_aggregates, :summary_source_updated_at, :datetime

    add_index :fact_aggregates, :summary_status
  end
end
