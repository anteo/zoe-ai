class SystemLog < ApplicationRecord
  CONSOLE_PAYLOAD_MAX_BYTES = 6_000
  CONSOLE_TRUNCATION_SUFFIX = "... [truncated]".freeze
  DEFAULT_LEVEL = "info"
  SEVERITY_LEVELS = %w[debug info warn error fatal].freeze
  SEVERITY_RANKS = SEVERITY_LEVELS.each_with_index.to_h.freeze

  validates :logged_at, :message, :severity, presence: true
  validates :severity, inclusion: { in: SEVERITY_LEVELS }

  before_validation :normalize_severity!
  before_validation :normalize_payload!
  before_validation :set_logged_at!

  scope :newest_first, -> { order(logged_at: :desc, id: :desc) }
  scope :for_level, ->(level) { where(severity: threshold_levels(level)) }

  def self.console_limit
    Setting.ui.admin_console_lines
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
    console_payload = {
      id: id,
      logged_at: logged_at.iso8601(3),
      message: "",
      severity: severity
    }
    console_payload[:message] = fit_console_value(console_payload, :message, message)

    if (details = console_error_details)
      fitted_details = fit_console_value(console_payload, :details, details)
      console_payload[:details] = fitted_details if fitted_details.present?
    end

    console_payload
  end

  private

  def console_error_details
    backtrace = Array(payload["error_backtrace"]).filter_map(&:presence)
    return if backtrace.empty?

    heading = [ payload["error_class"], payload["error_message"] ].filter_map(&:presence).join(": ")
    [ heading.presence, *backtrace ].compact.join("\n")
  end

  def fit_console_value(console_payload, key, value)
    value = value.to_s
    return value if console_payload.merge(key => value).to_json.bytesize <= CONSOLE_PAYLOAD_MAX_BYTES

    low = 0
    high = value.length
    fitted = nil

    while low <= high
      length = (low + high) / 2
      candidate = "#{value[0, length]}#{CONSOLE_TRUNCATION_SUFFIX}"

      if console_payload.merge(key => candidate).to_json.bytesize <= CONSOLE_PAYLOAD_MAX_BYTES
        fitted = candidate
        low = length + 1
      else
        high = length - 1
      end
    end

    fitted
  end

  def normalize_payload!
    self.payload = (payload || {}).deep_stringify_keys
  end

  def normalize_severity!
    self.severity = self.class.normalize_level(severity)
  end

  def set_logged_at!
    self.logged_at ||= Time.current
  end
end
