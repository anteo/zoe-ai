class EnforceNotNullOnFactsStaleKeys < ActiveRecord::Migration[8.0]
  def up
    change_column_null :facts, :character_id, false
    change_column_null :facts, :topic_id, false
    change_column_null :facts, :month, false
  end

  def down
    change_column_null :facts, :month, true
    change_column_null :facts, :topic_id, true
    change_column_null :facts, :character_id, true
  end
end
