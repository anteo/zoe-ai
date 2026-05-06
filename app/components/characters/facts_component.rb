module Characters
  class FactsComponent < ApplicationComponent
    attr_reader :character, :partner

    def initialize(character:, partner: nil)
      @character = character
      @partner = partner
    end

    def facts
      @facts ||= character.facts.includes(:topic, :author).order(mentioned_at: :desc, created_at: :desc)
    end

    def topic_options
      @topic_options ||= facts.filter_map { it.topic&.name.presence }.uniq.sort
    end

    def fact_persistence_icon(fact)
      fact.persistent? ? "icon-[lucide--check]" : ""
    end

    def fact_time_icon(fact)
      case fact.time
      when "past"
        "icon-[lucide--rewind]"
      when "future"
        "icon-[lucide--fast-forward]"
      else
        "icon-[lucide--play]"
      end
    end

    def fact_time_label(fact)
      case fact.time
      when "past"
        t(:label_time_past)
      when "future"
        t(:label_time_future)
      else
        t(:label_time_present)
      end
    end

    def fact_kind_icon(fact)
      case fact.kind.to_s
      when "attribute"
        "icon-[lucide--id-card]"
      when "experience"
        "icon-[lucide--sparkles]"
      when "belief"
        "icon-[lucide--lightbulb]"
      when "preference"
        "icon-[lucide--heart]"
      when "plan"
        "icon-[lucide--map]"
      else
        "icon-[lucide--tag]"
      end
    end

    def fact_kind_label(fact)
      t(:"label_fact_kind_#{fact.kind}")
    rescue I18n::MissingTranslationData
      fact.kind.to_s.humanize
    end

    def fact_date(fact)
      return unless fact.mentioned_at

      l(fact.mentioned_at.to_date)
    end

    def fact_time(fact)
      return unless fact.mentioned_at

      l(fact.mentioned_at, format: "%H:%M")
    end
  end
end
