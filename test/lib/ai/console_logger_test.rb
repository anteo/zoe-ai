require "test_helper"

class AI::ConsoleLoggerTest < ActiveSupport::TestCase
  test "broadcasts normalized payload" do
    broadcasts = []
    server = ActionCable.server
    original_broadcast = server.method(:broadcast)

    server.define_singleton_method(:broadcast) do |channel, payload|
      broadcasts << [ channel, payload ]
    end

    begin
      AI::ConsoleLogger.instance.info("hello")
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
    assert payload[:timestamp].present?
  end
end
