class EnforceNotNullOnFactAggregateAnchorMonth < ActiveRecord::Migration[8.0]
  def up
    change_column_null :fact_aggregates, :anchor_month, false
  end

  def down
    change_column_null :fact_aggregates, :anchor_month, true
  end
end
