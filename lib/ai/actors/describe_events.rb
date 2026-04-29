module AI::Actors
  class DescribeEvents < Actor
    input :character, type: Character
    input :mode, default: :xml
    input :maximum_count, default: -> { Setting.events.maximum_count }
    input :period_limit,  default: -> { Setting.events.period_limit }
    input :today, default: -> { Date.current }
    output :description
    output :groups

    TIME_FACT_PERIODS = {
      today: ->(today) { today..today },
      yesterday: ->(today) { today.yesterday..today.yesterday },
      earlier_this_month: ->(today) { today.beginning_of_month..today },
      past_3_months: ->(today) { today.months_ago(3)..today },
      past_6_months: ->(today) { today.months_ago(6)..today },
      earlier_this_year: ->(today) { today.beginning_of_year..today },
      older_past: ->(today) { ..today },
      tomorrow: ->(today) { today.tomorrow..today.tomorrow },
      later_this_month: ->(today) { today..today.end_of_month },
      next_3_months: ->(today) { today..today.months_since(3) },
      next_6_months: ->(today) { today..today.months_since(6) },
      later_this_year: ->(today) { today..today.end_of_year },
      future_later: ->(today) { today.. }
    }.freeze

    def call
      self.groups = grouped_events
      if groups.empty?
        self.description = ""
        return
      end

      self.description = render_template(groups).strip
    end

    private

    def grouped_events
      facts = event_facts
      groups = []
      selected_count = 0

      TIME_FACT_PERIODS.each do |key, period_builder|
        break if selected_count >= maximum_events_count

        period = period_builder.call(today)
        matching, facts = facts.partition { |fact| event_in_period?(fact, period) }
        next unless matching.any?

        limit = [ period_events_limit, maximum_events_count - selected_count ].min
        selected = matching.take(limit)
        next if selected.empty?

        selected_count += selected.size

        groups << {
          key:,
          period:,
          description: period_description(key),
          facts: selected
        }
      end

      groups
    end

    def event_facts
      character.facts_to_consider
               .persistent(false)
               .preload(:author, :topic)
               .order(importance: :desc, mentioned_at: :desc, id: :desc)
               .to_a
    end

    def event_in_period?(fact, period)
      date = event_date_for(fact)
      date && period.cover?(date)
    end

    def event_date_for(fact)
      fact.date_from || fact.date_to || fact.mentioned_date
    end

    def maximum_events_count
      maximum_count.to_i
    end

    def period_events_limit
      period_limit.to_i
    end

    def period_description(key)
      I18n.t(:"text_event_period_#{key}")
    end

    def render_template(groups)
      path = Rails.root.join("app/views/ai/actors/describe_events/#{mode_name}.txt.erb")
      unless File.exist?(path)
        raise ArgumentError, "Unsupported describe-events mode: #{mode.inspect}"
      end

      ERB.new(File.read(path), trim_mode: "-").result_with_hash(groups:)
    end

    def mode_name
      mode.to_s
    end
  end
end
