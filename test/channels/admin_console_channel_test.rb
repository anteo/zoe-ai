require "test_helper"

class AdminConsoleChannelTest < ActionCable::Channel::TestCase
  fixtures :users

  setup do
    @admin = users(:anton)
    @admin.update!(admin: true)
  end

  test "rejects non-admin subscriptions" do
    @admin.update!(admin: false)

    stub_connection current_user: @admin
    subscribe(level: "info")

    assert subscription.rejected?
  end

  test "sends snapshot limited by level threshold" do
    Setting.ui.update(admin_console_lines: 2)
    SystemLog.create!(severity: "info", message: "info", logged_at: 3.seconds.ago)
    warn_log = SystemLog.create!(severity: "warn", message: "warn", logged_at: 2.seconds.ago)
    error_log = SystemLog.create!(severity: "error", message: "error", logged_at: 1.second.ago)

    stub_connection current_user: @admin
    subscribe(level: "warn")

    assert subscription.confirmed?

    payload = transmissions.last.deep_symbolize_keys
    assert_equal "snapshot", payload[:type]
    assert_equal "warn", payload[:level]
    assert_equal 2, payload[:limit]
    assert_equal [ warn_log.id, error_log.id ], payload[:logs].map { |log| log.deep_symbolize_keys[:id] }
  end

  test "streams only rows matching the selected level" do
    stub_connection current_user: @admin
    subscribe(level: "error")

    warn_log = SystemLog.create!(severity: "warn", message: "warn", logged_at: 2.seconds.ago)
    error_log = SystemLog.create!(severity: "error", message: "error", logged_at: 1.second.ago)

    assert_no_changes -> { transmissions.size } do
      subscription.send(:handle_stream_payload, warn_log.to_console_payload)
    end

    assert_difference -> { transmissions.size }, 1 do
      subscription.send(:handle_stream_payload, error_log.to_console_payload)
    end

    payload = transmissions.last.deep_symbolize_keys
    assert_equal "append", payload[:type]
    assert_equal error_log.id, payload[:log].deep_symbolize_keys[:id]
  end

  test "limits snapshot payload size while keeping the latest logs" do
    Setting.ui.update(admin_console_lines: 100)
    20.times do |index|
      SystemLog.create!(
        severity: "error",
        message: "error #{index}",
        logged_at: index.seconds.ago,
        payload: { error_backtrace: Array.new(20, "x" * 500) }
      )
    end
    latest_log = SystemLog.newest_first.first

    stub_connection current_user: @admin
    subscribe(level: "error")

    payload = transmissions.last.deep_symbolize_keys
    assert_operator payload.to_json.bytesize, :<=, AdminConsoleChannel::SNAPSHOT_MAX_BYTES
    assert_equal latest_log.id, payload[:logs].last[:id]
  end
end
