# frozen_string_literal: true

class CharacterEventsComponent < ApplicationComponent
  attr_reader :character

  def initialize(character:)
    @character = character
  end

  def groups
    @groups ||= events_result.groups
  end

  def events?
    groups.any?
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
    @events_result ||= AI::Actors::DescribeEvents.result(character:, mode: :markdown)
  end

  def fact_date(fact)
    return unless fact.mentioned_at

    l(fact.mentioned_at.to_date)
  end
end
