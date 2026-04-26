module AI
  module Tools
    class EventSearch < Tool
      description "Search time-bound remembered events, plans, and recent happenings about known characters."

      params do
        string :query,
               description: "Optional text to search for in event content, topic, or character name",
               required: false
        integer :character_id,
                description: "Optional character ID from the <characters> system prompt section to restrict the search",
                required: false
        string :time,
               description: "Optional time filter",
               enum: %w[past present future],
               required: false
        string :date_from,
               description: "Optional start date in YYYY-MM-DD",
               required: false
        string :date_to,
               description: "Optional end date in YYYY-MM-DD",
               required: false
        integer :limit,
                description: "Maximum number of events to return",
                required: false
      end

      def execute(query: nil, character_id: nil, time: nil, date_from: nil, date_to: nil, limit: default_limit)
        facts = scoped_event_facts
        facts = facts.where(character: find_character!(character_id)) if character_id.present?
        facts = facts.where(time:) if time.present?
        facts = apply_date_filter(facts, date_from:, date_to:)
        facts = apply_text_filter(facts, query) if query.present?

        events = facts.order(importance: :desc, mentioned_at: :desc, id: :desc)
                      .limit(normalized_limit(limit))
                      .to_a

        return "No matching events found." if events.empty?

        render_events(events)
      end

      private

      def scoped_event_facts
        Fact.where(character: accessible_characters)
            .persistent(false)
            .includes(:character, :author, :topic)
            .references(:character, :author, :topic)
      end

      def accessible_characters
        current_user.characters
      end

      def find_character!(id)
        character = accessible_characters.find_by(id:)
        fail! "Known character not found: #{id}" unless character

        character
      end

      def apply_text_filter(facts, query)
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
        facts.joins(:character, :topic).where(
          "facts.content ILIKE :pattern OR topics.name ILIKE :pattern OR characters.name ILIKE :pattern",
          pattern:
        )
      end

      def apply_date_filter(facts, date_from:, date_to:)
        from = parse_date(date_from, "date_from") if date_from.present?
        to = parse_date(date_to, "date_to") if date_to.present?

        facts = facts.where("COALESCE(facts.date_from, facts.date_to, DATE(facts.mentioned_at)) >= ?", from) if from
        facts = facts.where("COALESCE(facts.date_from, facts.date_to, DATE(facts.mentioned_at)) <= ?", to) if to
        facts
      end

      def parse_date(value, name)
        Date.iso8601(value)
      rescue Date::Error
        fail! "#{name} must be in YYYY-MM-DD format"
      end

      def normalized_limit(value)
        value.to_i.clamp(1, max_limit)
      end

      def default_limit
        ENV.fetch("ZOE_EVENT_SEARCH_DEFAULT_LIMIT", 10).to_i
      end

      def max_limit
        ENV.fetch("ZOE_EVENT_SEARCH_MAX_LIMIT", 20).to_i
      end

      def render_events(events)
        events.map do |fact|
          <<~XML.strip
            <event character="#{h(fact.character)}" date="#{h(fact.prompt_date)}" time="#{h(fact.time)}" kind="#{h(fact.kind)}" topic="#{h(fact.topic)}" importance="#{fact.importance}" source="#{h(fact.prompt_source)}">#{h(fact.content)}</event>
          XML
        end.join("\n")
      end

      def h(value)
        ERB::Util.html_escape(value.to_s)
      end
    end
  end
end
