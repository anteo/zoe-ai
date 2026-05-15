module Characters
  class EventsComponent < SectionComponent
    def badge_count
      groups.sum { it[:facts].size }
    end

    def groups
      @groups ||= events_result.groups
    end

    def events?
      groups.any?
    end

    def section_icon_class
      "icon-[lucide--calendar-days]"
    end

    def visible?
      events?
    end

    def event_date(fact)
      fact.prompt_date.presence || fact_date(fact)
    end

    def event_time(fact)
      return unless fact.mentioned_at

      l(fact.mentioned_at, format: "%H:%M")
    end

    private

    def events_result
      @events_result ||= AI::Actors::DescribeEvents.result(character:, partner:, mode: :markdown)
    end

    def fact_date(fact)
      return unless fact.mentioned_at

      l(fact.mentioned_at.to_date)
    end
  end
end
