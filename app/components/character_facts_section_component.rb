# frozen_string_literal: true

class CharacterFactsSectionComponent < ApplicationComponent
  attr_reader :character

  def initialize(character:)
    @character = character
  end

  def facts
    @facts ||= character.facts.includes(:topic, :author).order(mentioned_at: :desc, created_at: :desc)
  end

  def fact_tags(fact)
    [
      fact.topic&.name,
      fact.kind.to_s.humanize.presence,
      (fact.persistent? ? t(:label_persistent) : t(:label_event)),
      fact.time.to_s.humanize.presence
    ].compact
  end

  def fact_date(fact)
    return unless fact.mentioned_at

    l(fact.mentioned_at.to_date)
  end
end
