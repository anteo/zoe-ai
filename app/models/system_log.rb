class SystemLog < ApplicationRecord
  DEFAULT_LEVEL = "info"
  SEVERITY_LEVELS = %w[debug info warn error fatal].freeze
  SEVERITY_RANKS = SEVERITY_LEVELS.each_with_index.to_h.freeze

  validates :logged_at, :message, :severity, :source, presence: true
  validates :severity, inclusion: { in: SEVERITY_LEVELS }

  before_validation :normalize_severity!
  before_validation :set_logged_at!

  scope :newest_first, -> { order(logged_at: :desc, id: :desc) }
  scope :for_level, ->(level) { where(severity: threshold_levels(level)) }

  def self.console_limit
    Setting.ai.admin_console_lines
  end

  def self.matches_level?(severity, level)
    rank(normalize_level(severity)) >= rank(level)
  end

  def self.normalize_level(level)
    candidate = level.to_s
    SEVERITY_RANKS.key?(candidate) ? candidate : DEFAULT_LEVEL
  end

  def self.rank(level)
    SEVERITY_RANKS.fetch(normalize_level(level))
  end

  def self.threshold_levels(level)
    minimum_rank = rank(level)
    SEVERITY_LEVELS.select { |severity| rank(severity) >= minimum_rank }
  end

  def self.recent_for_level(level, limit: console_limit)
    for_level(level).newest_first.limit(limit).to_a.reverse
  end

  def to_console_payload
    {
      id: id,
      logged_at: logged_at.iso8601(3),
      message: message,
      severity: severity,
      source: source
    }
  end

  private

  def normalize_severity!
    self.severity = self.class.normalize_level(severity)
  end

  def set_logged_at!
    self.logged_at ||= Time.current
  end
end
