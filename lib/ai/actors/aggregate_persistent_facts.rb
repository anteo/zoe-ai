module AI::Actors
  class AggregatePersistentFacts < Actor
    input :character, type: Character
    input :partner, type: Character
    input :logger, default: -> { Rails.logger }

    fail_on ActiveRecord::RecordInvalid

    def call
      month_rows_to_summarize = []

      FactAggregate.transaction do
        tagged_logger.info("Start aggregating facts (#{refresh_mode})...")
        month_rows = refresh_months(scope_fact_aggregates.months.index_by(&:slot_key))
        month_rows_to_summarize = month_rows.values.select { it.dirty? && !it.marked_for_destruction? }

        band_rows = if refresh_mode == :current_rotation
          refresh_all_bands(month_rows)
        else
          refresh_stale_bands(month_rows)
        end

        tagged_logger.info "Aggregation finished."

        flush_pending_changes!(band_rows.values)
        link_month_rows_to_band_rows(month_rows, band_rows)
        flush_pending_changes!(month_rows.values)
        cleanup_stale_band_anchors
      end

      enqueue_month_summarization(month_rows_to_summarize)
    end

    private

    def refresh_months(existing_month_rows)
      month_groups = refresh_month_groups(existing_month_rows)
      slot_keys = month_groups.map { |topic_id, bucket_month| month_slot_key(topic_id, bucket_month) }

      refreshed_rows = refresh_aggregates(
        source_rows: load_facts_for_month_groups(month_groups),
        existing_rows: existing_month_rows.slice(*slot_keys),
        group_by: ->(fact) { [ fact.topic_id, fact.month ] },
        slot_key_for_group: ->(topic_id, bucket_month) { month_slot_key(topic_id, bucket_month) },
        build_attributes: method(:build_month_attributes)
      )

      existing_month_rows.merge(refreshed_rows)
    end

    def refresh_month_groups(existing_month_rows)
      fact_month_groups = existing_fact_month_groups
      missing_groups = fact_month_groups.reject { |topic_id, bucket_month| existing_month_rows.key?(month_slot_key(topic_id, bucket_month)) }
      stale_groups = existing_month_rows.values.select(&:stale?).map { |row| [ row.topic_id, row.anchor_month ] }

      (missing_groups + stale_groups).uniq
    end

    def existing_fact_month_groups
      facts_scope
        .group(:topic_id, :month)
        .pluck(:topic_id, :month)
    end

    def load_facts_for_month_groups(month_groups)
      return [] if month_groups.empty?

      scoped_facts = month_groups.reduce(facts_scope.none) do |scope, (topic_id, bucket_month)|
        scope.or(facts_scope.where(topic_id:, month: bucket_month))
      end

      scoped_facts.includes(:author, :topic)
                 .order(:topic_id, :mentioned_at, :id)
                 .to_a
    end

    def facts_scope
      character.facts_to_consider
               .where(partner:)
               .persistent
               .where.not(topic_id: nil, month: nil)
    end

    def build_month_attributes((_, anchor_month), grouped_facts)
      {
        kind: "month",
        anchor_month: anchor_month,
        body: format_body(anchor_month, format_facts(grouped_facts)),
        facts_count: grouped_facts.size,
        source_updated_at: grouped_facts.filter_map(&:updated_at).max,
        summary_status: "pending",
        summary_source_updated_at: nil,
        stale: false
      }
    end

    def refresh_aggregates(source_rows:, existing_rows:, group_by:, slot_key_for_group:, build_attributes:)
      grouped = source_rows.reject(&:marked_for_destruction?).group_by(&group_by)
      current_rows = {}

      grouped.map do |group_key, rows|
        slot_key = slot_key_for_group.call(*group_key)
        attrs = build_attributes.call(group_key, rows)
        topic_id = group_key.first

        aggregate = existing_rows[slot_key] || FactAggregate.new(character:, partner:, topic_id:)
        aggregate.assign_attributes(attrs)
        current_rows[slot_key] = aggregate
      end

      stale_rows = existing_rows.except(*current_rows.keys)
      stale_rows.values.each(&:mark_for_destruction)

      current_rows.merge(stale_rows)
    end

    def refresh_all_bands(rows)
      refresh_aggregates(
        source_rows: rows.values,
        existing_rows: current_anchor_band_rows,
        group_by: ->(row) { [ row.topic_id, row.band_kind_for(anchor_month) ] },
        slot_key_for_group: ->(topic_id, band_kind) {
          band_slot_key(topic_id, band_kind)
        },
        build_attributes: method(:build_band_attributes)
      )
    end

    def refresh_stale_bands(rows)
      grouped_month_rows = rows.values.reject(&:marked_for_destruction?).group_by do |row|
        band_slot_key(row.topic_id, row.band_kind_for(anchor_month))
      end
      existing_band_rows = current_anchor_band_rows
      touched_slot_keys = rows.filter_map do |_, row|
        next unless row&.dirty? || row&.marked_for_destruction?
        band_slot_key(row.topic_id, row.band_kind_for(anchor_month))
      end.uniq

      orphan_slot_keys = touched_slot_keys.reject { |slot_key| grouped_month_rows.key?(slot_key) }
      orphan_rows = existing_band_rows.slice(*orphan_slot_keys)
      orphan_rows.values.each(&:mark_for_destruction)

      slot_keys = grouped_month_rows.filter_map do |slot_key, rows|
        band_row = existing_band_rows[slot_key]
        max_source_updated_at = rows.filter_map(&:source_updated_at).max

        next slot_key if band_row.nil?
        next slot_key if touched_slot_keys.include?(slot_key)
        next slot_key if band_row.source_updated_at != max_source_updated_at

        nil
      end

      return orphan_rows if slot_keys.empty?

      relevant_month_rows = slot_keys.flat_map { |slot_key| grouped_month_rows.fetch(slot_key) }
      existing_rows = existing_band_rows.slice(*slot_keys)

      rows = refresh_aggregates(
        source_rows: relevant_month_rows,
        existing_rows: existing_rows,
        group_by: ->(row) { [ row.topic_id, row.band_kind_for(anchor_month) ] },
        slot_key_for_group: ->(topic_id, band_kind) {
          band_slot_key(topic_id, band_kind)
        },
        build_attributes: method(:build_band_attributes)
      )

      rows.merge(orphan_rows)
    end

    def build_band_attributes((_, band_kind), rows)
      ordered_rows = rows.sort_by(&:anchor_month)

      {
        kind: band_kind,
        anchor_month: anchor_month,
        body: ordered_rows.map(&:body).join("\n\n"),
        facts_count: ordered_rows.sum(&:facts_count),
        source_updated_at: ordered_rows.filter_map(&:source_updated_at).max,
        summary_status: "pending",
        summary_source_updated_at: nil,
        stale: false
      }
    end

    def format_facts(facts)
      facts.map { "- #{it.to_description}" }.join("\n")
    end

    def format_body(anchor_month, body)
      "## #{anchor_month.strftime("%B %Y")}\n#{body}"
    end

    def current_band_anchor_month
      @current_band_anchor_month ||= scope_fact_aggregates.bands.latest_anchor_month
    end

    def refresh_mode
      return :current_rotation if current_band_anchor_month && current_band_anchor_month < anchor_month

      :current_refresh
    end

    def anchor_month
      @anchor_month ||= Date.current.beginning_of_month
    end

    def current_anchor_band_rows
      scope_fact_aggregates
               .bands
               .where(anchor_month:)
               .index_by(&:slot_key)
    end

    def cleanup_stale_band_anchors
      scope_fact_aggregates
               .bands
               .where.not(anchor_month:)
               .delete_all
    end

    def link_month_rows_to_band_rows(month_rows, band_rows)
      month_rows.each_value do |month_row|
        next if month_row.marked_for_destruction?

        parent = band_rows[band_slot_key(month_row.topic_id, month_row.band_kind_for(anchor_month))]
        next unless parent
        next if parent&.persisted? && month_row.parent_id == parent.id

        month_row.parent = parent
      end
    end

    def month_slot_key(topic_id, bucket_month)
      FactAggregate.slot_key_for(character_id: character.id, partner_id: partner.id, topic_id:, kind: "month", anchor_month: bucket_month)
    end

    def band_slot_key(topic_id, band_kind)
      FactAggregate.slot_key_for(character_id: character.id, partner_id: partner.id, topic_id:, kind: band_kind, anchor_month:)
    end

    def scope_fact_aggregates
      character.fact_aggregates.where(partner:)
    end

    def flush_pending_changes!(rows)
      rows_to_save = rows.uniq.select { !it.marked_for_destruction? && it.dirty? }
      rows_to_destroy = rows.uniq.select(&:marked_for_destruction?)

      rows_to_save.each(&:save!)
      tagged_logger.info "Changed rows: #{rows_to_save.map(&:slot_key).join(', ')}" if rows_to_save.any?

      rows_to_destroy.each(&:destroy!)
      tagged_logger.info "Deleted rows: #{rows_to_destroy.map(&:slot_key).join(', ')}" if rows_to_destroy.any?
    end

    def enqueue_month_summarization(rows)
      rows.each do |row|
        SummarizeFactAggregateJob.perform_later(row)
      end
    end

    def tagged_logger
      logger.tagged("AggregatePersistentFacts")
            .tagged("character_id=#{character.id}")
            .tagged("partner_id=#{partner.id}")
            .tagged("anchor_month=#{anchor_month}")
    end
  end
end
