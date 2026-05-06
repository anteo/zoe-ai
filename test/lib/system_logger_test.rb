require "test_helper"
require "stringio"

class SystemLoggerTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    SystemLog.delete_all
  end

  teardown do
    SystemLog.delete_all
  end

  test "persists and broadcasts normalized payload" do
    broadcasts = []
    server = ActionCable.server
    original_broadcast = server.method(:broadcast)

    server.define_singleton_method(:broadcast) do |channel, payload|
      broadcasts << [ channel, payload ]
    end

    begin
      SystemLogger.instance.info("hello")
      SystemLogger.flush
    ensure
      server.define_singleton_method(:broadcast) do |*args, **kwargs, &block|
        original_broadcast.call(*args, **kwargs, &block)
      end
    end

    assert_equal 1, broadcasts.size
    channel, payload = broadcasts.first
    assert_equal AdminConsoleChannel::STREAM, channel
    assert_equal "info", payload[:severity]
    assert_equal "hello", payload[:message]
    assert_nil payload[:payload]
    assert payload[:logged_at].present?

    record = SystemLog.last
    assert_equal "info", record.severity
    assert_equal "hello", record.message
    assert_equal({}, record.payload)
  end

  test "persists logs even when caller transaction rolls back" do
    ApplicationRecord.transaction do
      SystemLogger.instance.info("survives rollback")
      raise ActiveRecord::Rollback
    end

    SystemLogger.flush

    assert SystemLog.exists?(message: "survives rollback")
  end

  test "persists logs with payload context" do
    SystemLogger.instance.with_payload(source: "job").info("hello from job", request_id: "abc123")
    SystemLogger.flush

    record = SystemLog.last
    assert_equal "hello from job", record.message
    assert_equal({ "request_id" => "abc123", "source" => "job" }, record.payload)
  end

  test "uses block content for standard logger methods" do
    SystemLogger.instance.info(request_id: "abc123") { "hello from block" }
    SystemLogger.flush

    record = SystemLog.last
    assert_equal "hello from block", record.message
    assert_equal({ "request_id" => "abc123" }, record.payload)
  end

  test "accepts logger add progname argument" do
    SystemLogger.instance.add(Logger::INFO, nil, "hello from progname", request_id: "abc123")
    SystemLogger.flush

    record = SystemLog.last
    assert_equal "hello from progname", record.message
    assert_equal({ "request_id" => "abc123" }, record.payload)
  end

  test "works with broadcast logger" do
    io = StringIO.new
    ruby_logger = Logger.new(io)
    logger = ActiveSupport::BroadcastLogger.new(ruby_logger, SystemLogger.instance)

    logger.info(request_id: "abc123") { "hello from broadcast" }
    SystemLogger.flush

    assert_includes io.string, "hello from broadcast"
    record = SystemLog.last
    assert_equal "hello from broadcast", record.message
    assert_equal({ "request_id" => "abc123" }, record.payload)
  end
end
