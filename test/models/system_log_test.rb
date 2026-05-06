require "test_helper"

class SystemLogTest < ActiveSupport::TestCase
  test "recent_for_level returns threshold-matching rows in chronological order" do
    travel_to Time.zone.local(2026, 5, 5, 12, 0, 0) do
      debug_log = SystemLog.create!(severity: "debug", message: "debug", logged_at: 3.seconds.ago)
      warn_log = SystemLog.create!(severity: "warn", message: "warn", logged_at: 2.seconds.ago)
      error_log = SystemLog.create!(severity: "error", message: "error", logged_at: 1.second.ago)

      assert_equal [ warn_log, error_log ], SystemLog.recent_for_level("warn", limit: 5)
      assert_equal [ error_log ], SystemLog.recent_for_level("error", limit: 1)
      assert_not_includes SystemLog.recent_for_level("warn", limit: 5), debug_log
    end
  end

  test "normalizes unsupported severities to info" do
    log = SystemLog.create!(severity: "unknown", message: "hello")

    assert_equal "info", log.severity
  end
end
