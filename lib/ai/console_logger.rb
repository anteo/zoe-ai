# frozen_string_literal: true

require "logger"
require "singleton"

module AI
  class ConsoleLogger < ::Logger
    include Singleton

    CHANNEL = AdminConsoleChannel::STREAM
    SOURCE = "rubyllm"
    THREAD_GUARD_KEY = :ai_console_logger_broadcasting
    MAX_BROADCAST_MESSAGE_BYTES = 6_000
    TRUNCATION_SUFFIX = "... [truncated]"
    SEVERITIES = {
      ::Logger::DEBUG => "debug",
      ::Logger::INFO => "info",
      ::Logger::WARN => "warn",
      ::Logger::ERROR => "error",
      ::Logger::FATAL => "fatal",
      ::Logger::UNKNOWN => "unknown"
    }.freeze

    def initialize
      super(IO::NULL)
      self.level = ::Logger::DEBUG
    end

    def add(severity, message = nil, progname = nil, &block)
      return true if Thread.current[THREAD_GUARD_KEY]
      return true unless severity.to_i >= level

      line = safe_broadcast_line(normalize_line(message, progname, block))
      return true if line.empty?

      begin
        Thread.current[THREAD_GUARD_KEY] = true
        ActionCable.server.broadcast(CHANNEL, {
          source: SOURCE,
          severity: SEVERITIES.fetch(severity, "unknown"),
          message: line,
          timestamp: Time.current.iso8601(3)
        })
      ensure
        Thread.current[THREAD_GUARD_KEY] = false
      end

      true
    end

    private

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
