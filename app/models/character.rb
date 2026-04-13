class Character < ApplicationRecord
  has_many_attached :images

  belongs_to :user, optional: true

  has_many :facts, dependent: :delete_all
  has_many :instructions, dependent: :delete_all
  has_many :chats, class_name: "Chat", foreign_key: :character_id, dependent: :destroy
  has_many :partner_chats, class_name: "Chat", foreign_key: :partner_id, dependent: :destroy

  scope :human, -> { where(ai: false) }

  def self.ai
    RequestStore[:ai] ||= where(ai: true).first
  end

  PERSISTENT_FACT_PERIODS = [
    (...12.months.ago),
    (12.months.ago...6.months.ago),
    (6.months.ago...3.months.ago),
    (3.months.ago...)
  ].freeze

  TIME_FACT_PERIODS = [
    {
      period: (Date.today..Date.today),
      desc: "happened or will happen today"
    },
    {
      period: (Date.yesterday..Date.yesterday),
      desc: "happened yesterday"
    },
    {
      period: (Date.today.beginning_of_month..Date.today),
      desc: "happened earlier this month"
    },
    {
      period: (Date.today.months_ago(3)..Date.today),
      desc: "happened earlier within the last 3 months"
    },
    {
      period: (Date.today.months_ago(6)..Date.today),
      desc: "happened earlier within the last 6 months"
    },
    {
      period: (Date.today.beginning_of_year..Date.today),
      desc: "happened earlier this year"
    },
    {
      period: (..Date.today),
      desc: "happened earlier"
    },
    {
      period: (Date.tomorrow..Date.tomorrow),
      desc: "will happen tomorrow"
    },
    {
      period: (Date.today..Date.today.end_of_month),
      desc: "will happen later this month"
    },
    {
      period: (Date.today..Date.today.months_since(3)),
      desc: "will happen later within the next 3 months"
    },
    {
      period: (Date.today..Date.today.months_since(6)),
      desc: "will happen later within the next 6 months"
    },
    {
      period: (Date.today..Date.today.end_of_year),
      desc: "will happen later this year"
    },
    {
      period: (Date.today..),
      desc: "will happen later"
    },
  ]

  def initials
    name.split.first(2).map { _1[0] }.join.upcase
  end

  def to_s
    name
  end

  def last_conversation_time
    last = user_chats.order(:created_at).last
    return unless last
    last.messages.maximum(:created_at)
  end

  def facts_to_consider
    ai? ? facts.excluding_kind("belief") : facts
  end

  def grouped_persistent_facts
    scope = facts_to_consider.persistent.preload(:topic).order(:mentioned_at)
    PERSISTENT_FACT_PERIODS.filter_map do |period|
      facts = scope.where(mentioned_at: period)
      next unless facts.any?

      [ period, facts.to_a ]
    end
  end

  def grouped_time_facts(maximum_count: 10)
    facts = facts_to_consider.persistent(false).preload(:topic).order(importance: :desc).to_a

    TIME_FACT_PERIODS.filter_map do |p|
      period = p[:period]
      desc = p[:desc]

      matching, facts = facts.partition { it.period && period.cover?(it.period) }
      next unless matching.any?

      [ period, desc, matching.take(maximum_count) ]
    end
  end
end
