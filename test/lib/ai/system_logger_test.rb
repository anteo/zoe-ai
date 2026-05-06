require "test_helper"

class AI::SystemLoggerTest < ActiveSupport::TestCase
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
      AI::SystemLogger.instance.info("hello")
      AI::SystemLogger.flush
    ensure
      server.define_singleton_method(:broadcast) do |*args, **kwargs, &block|
        original_broadcast.call(*args, **kwargs, &block)
      end
    end

    assert_equal 1, broadcasts.size
    channel, payload = broadcasts.first
    assert_equal AdminConsoleChannel::STREAM, channel
    assert_equal "rubyllm", payload[:source]
    assert_equal "info", payload[:severity]
    assert_equal "hello", payload[:message]
    assert payload[:logged_at].present?

    record = SystemLog.last
    assert_equal "rubyllm", record.source
    assert_equal "info", record.severity
    assert_equal "hello", record.message
  end

  test "persists logs even when caller transaction rolls back" do
    ApplicationRecord.transaction do
      AI::SystemLogger.instance.info("survives rollback")
      raise ActiveRecord::Rollback
    end

    AI::SystemLogger.flush

    assert SystemLog.exists?(message: "survives rollback")
  end
end
