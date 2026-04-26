module AI::Actors
  class SummarizeFactAggregate < Actor
    input :fact_aggregate, type: FactAggregate
    input :logger, default: -> { Rails.logger }

    fail_on RubyLLM::Error,
            ActiveRecord::RecordInvalid

    def call
      fact_aggregate.reload
      return unless summarizable?

      source_updated_at = source_updated_at_for(fact_aggregate)
      return if fact_aggregate.done? && fact_aggregate.summary_source_updated_at == source_updated_at

      fact_aggregate.update!(summary_status: "in_progress")
      summary = summarize
      fact_aggregate.reload
      return unless source_updated_at_for(fact_aggregate) == source_updated_at

      fact_aggregate.update!(
        summary: summary,
        summary_status: "done",
        summary_source_updated_at: source_updated_at
      )

      enqueue_parent_if_ready if fact_aggregate.month?
    rescue
      fact_aggregate&.update!(summary_status: "failed")
      raise
    end

    private

    def summarizable?
      return true if fact_aggregate.month?

      fact_aggregate.children.exists? && fact_aggregate.children.all?(&:done?)
    end

    def summarize
      response = AI::Agents::SummarizeFactAggregate.chat(fact_aggregate:).ask(source_text)
      response.content.to_s
    end

    def source_text
      if fact_aggregate.month?
        fact_aggregate.body
      else
        fact_aggregate.source_records.map do |child|
          "## #{child.anchor_month.strftime("%B %Y")}\n#{child.summary}"
        end.join("\n\n")
      end
    end

    def source_updated_at_for(aggregate)
      if aggregate.month?
        aggregate.source_updated_at
      else
        aggregate.children.maximum(:summary_source_updated_at)
      end
    end

    def enqueue_parent_if_ready
      parent = fact_aggregate.parent
      return unless parent
      return unless parent.children.exists?
      return unless parent.children.all?(&:done?)

      SummarizeFactAggregateJob.perform_later(parent)
    end
  end
end
