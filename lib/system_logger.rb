require "logger"
require "timeout"

class SystemLogger
  SEVERITY_LEVELS = {
    debug: Logger::DEBUG,
    info: Logger::INFO,
    warn: Logger::WARN,
    error: Logger::ERROR,
    fatal: Logger::FATAL,
    unknown: Logger::UNKNOWN
  }.freeze

  CHANNEL = AdminConsoleChannel::STREAM
  THREAD_GUARD_KEY = :system_logger_broadcasting
  MAX_BROADCAST_MESSAGE_BYTES = 6_000
  TRUNCATION_SUFFIX = "... [truncated]"

  attr_reader :level, :payload

  class << self
    def instance
      @instance ||= new
    end

    def flush(timeout: 2)
      start_consumer!

      acknowledgements = Queue.new
      queue << { control: :flush, acknowledgements: }

      Timeout.timeout(timeout) { acknowledgements.pop }
    end

    def publish(payload)
      start_consumer!
      queue << payload
    end

    private

    def consumer_mutex
      @consumer_mutex ||= Mutex.new
    end

    def queue
      @queue ||= Queue.new
    end

    def start_consumer!
      consumer_mutex.synchronize do
        return if @consumer_thread&.alive?

        @consumer_thread = Thread.new do
          Thread.current.name = "system-log-writer" if Thread.current.respond_to?(:name=)

          loop do
            entry = queue.pop

            if entry[:control] == :flush
              entry[:acknowledgements] << true
              next
            end

            persist_and_broadcast!(entry)
          end
        rescue StandardError => e
          STDERR.puts("[SystemLogger] consumer failed: #{e.class}: #{e.message}")
          retry
        end
      end
    end

    def persist_and_broadcast!(payload)
      record = nil

      ActiveRecord::Base.connection_pool.with_connection do
        record = SystemLog.create!(
          logged_at: payload[:logged_at],
          message: payload[:message],
          severity: payload[:severity],
          payload: payload[:payload]
        )
      end

      ActionCable.server.broadcast(CHANNEL, record.to_console_payload)
    rescue StandardError => e
      STDERR.puts("[SystemLogger] persist failed: #{e.class}: #{e.message}")
    end
  end

  def initialize(level: Logger::DEBUG, payload: {})
    self.level = level
    self.payload = payload
    self.class.send(:start_consumer!)
  end

  def level=(value)
    @level = severity_value(value)
  end

  def payload=(value)
    @payload = normalize_payload(value || {})
  end

  def with_payload(**payload)
    self.class.new(level:, payload: self.payload.merge(normalize_payload(payload)))
  end

  def add(severity, message = nil, **payload)
    return true if Thread.current[THREAD_GUARD_KEY]
    return true unless severity_value(severity) >= level

    line = safe_broadcast_line(message.to_s)
    return true if line.empty?

    begin
      Thread.current[THREAD_GUARD_KEY] = true
      self.class.publish(
        logged_at: Time.current,
        message: line,
        payload: normalize_payload(self.payload.merge(payload)),
        severity: SystemLog.normalize_level(severity_name(severity))
      )
    ensure
      Thread.current[THREAD_GUARD_KEY] = false
    end

    true
  end

  def log(severity, message = nil, **payload)
    add(severity, message, **payload)
  end

  def debug(message = nil, **payload)
    add(:debug, message, **payload)
  end

  def info(message = nil, **payload)
    add(:info, message, **payload)
  end

  def warn(message = nil, **payload)
    add(:warn, message, **payload)
  end

  def error(message = nil, **payload)
    add(:error, message, **payload)
  end

  def fatal(message = nil, **payload)
    add(:fatal, message, **payload)
  end

  def unknown(message = nil, **payload)
    add(:unknown, message, **payload)
  end

  def debug?
    level <= Logger::DEBUG
  end

  def info?
    level <= Logger::INFO
  end

  def warn?
    level <= Logger::WARN
  end

  def error?
    level <= Logger::ERROR
  end

  def fatal?
    level <= Logger::FATAL
  end

  def close
  end

  private

  def severity_name(severity)
    return SEVERITY_LEVELS.key(severity)&.to_s if severity.is_a?(Integer)

    severity.to_s
  end

  def severity_value(severity)
    return severity if severity.is_a?(Integer)

    SEVERITY_LEVELS.fetch(severity.to_sym, Logger::INFO)
  rescue NoMethodError, KeyError
    Logger::INFO
  end

  def normalize_payload(payload)
    payload.to_h.deep_stringify_keys
  end

  def safe_broadcast_line(line)
    line.truncate(MAX_BROADCAST_MESSAGE_BYTES, omission: TRUNCATION_SUFFIX)
  end
end
