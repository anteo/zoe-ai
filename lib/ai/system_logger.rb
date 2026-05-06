# frozen_string_literal: true

require "logger"
require "singleton"
require "timeout"

module AI
  class SystemLogger < ::Logger
    include Singleton

    CHANNEL = AdminConsoleChannel::STREAM
    SOURCE = "rubyllm"
    THREAD_GUARD_KEY = :ai_system_logger_broadcasting
    MAX_BROADCAST_MESSAGE_BYTES = 6_000
    TRUNCATION_SUFFIX = "... [truncated]"

    class << self
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
            Thread.current.name = "ai-system-log-writer" if Thread.current.respond_to?(:name=)

            loop do
              entry = queue.pop

              if entry[:control] == :flush
                entry[:acknowledgements] << true
                next
              end

              persist_and_broadcast!(entry)
            end
          rescue StandardError => e
            STDERR.puts("[AI::SystemLogger] consumer failed: #{e.class}: #{e.message}")
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
            source: payload[:source]
          )
        end

        ActionCable.server.broadcast(CHANNEL, record.to_console_payload)
      rescue StandardError => e
        STDERR.puts("[AI::SystemLogger] persist failed: #{e.class}: #{e.message}")
      end
    end

    def initialize
      super(IO::NULL)
      self.level = ::Logger::DEBUG
      self.class.send(:start_consumer!)
    end

    def add(severity, message = nil, progname = nil, &block)
      return true if Thread.current[THREAD_GUARD_KEY]
      return true unless severity.to_i >= level

      line = safe_broadcast_line(normalize_line(message, progname, block))
      return true if line.empty?

      begin
        Thread.current[THREAD_GUARD_KEY] = true
        self.class.publish(
          logged_at: Time.current,
          message: line,
          severity: SystemLog.normalize_level(logger_severity(severity)),
          source: SOURCE
        )
      ensure
        Thread.current[THREAD_GUARD_KEY] = false
      end

      true
    end

    private

    def logger_severity(severity)
      case severity
      when ::Logger::DEBUG then "debug"
      when ::Logger::INFO then "info"
      when ::Logger::WARN then "warn"
      when ::Logger::ERROR then "error"
      when ::Logger::FATAL then "fatal"
      else SystemLog::DEFAULT_LEVEL
      end
    end

    def normalize_line(message, progname, block)
      value = if message.nil?
        block&.call || progname || @progname
      else
        message
      end
      value.to_s
    end

    def safe_broadcast_line(line)
      line.truncate(MAX_BROADCAST_MESSAGE_BYTES, omission: TRUNCATION_SUFFIX)
    end
  end
end
