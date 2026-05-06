module AI::Actors
  class SummarizeFactAggregate < Actor
    input :fact_aggregate, type: FactAggregate
    input :logger, default: -> { Rails.logger }

    fail_on RubyLLM::Error,
            ActiveRecord::RecordInvalid

    def call
      return unless fact_aggregate.summarizable?

      source_updated_at = fact_aggregate.current_summary_source_updated_at

      fact_aggregate.update!(summary_status: "in_progress")
      summary = summarize

      fact_aggregate.reload
      unless fact_aggregate.current_summary_source_updated_at == source_updated_at
        fact_aggregate.update!(summary_status: "pending")
        return
      end

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

    def enqueue_parent_if_ready
      parent = fact_aggregate.parent
      return unless parent
      return unless parent.needs_summary_refresh?

      SummarizeFactAggregateJob.perform_later(parent)
    end
  end
end
