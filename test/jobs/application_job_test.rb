require "test_helper"

class ApplicationJobTest < ActiveJob::TestCase
  class LoggingSuccessJob < ApplicationJob
    def perform
    end
  end

  class LoggingFailureJob < ApplicationJob
    def perform
      raise "boom"
    end
  end

  test "logs job start and finish" do
    entries = capture_system_logger do
      LoggingSuccessJob.perform_now
    end

    assert_equal 2, entries.size
    assert_equal :info, entries[0][:level]
    assert_equal "ApplicationJobTest::LoggingSuccessJob starting...", entries[0][:message]
    assert_equal "ApplicationJobTest::LoggingSuccessJob", entries[0][:payload]["job_class"]
    assert entries[0][:payload]["job_id"].present?
    assert_equal :info, entries[1][:level]
    assert_equal "ApplicationJobTest::LoggingSuccessJob finished.", entries[1][:message]
    assert_equal "ApplicationJobTest::LoggingSuccessJob", entries[1][:payload]["job_class"]
    assert entries[1][:payload]["job_id"].present?
  end

  test "logs job errors and reraises" do
    entries = capture_system_logger do
      error = assert_raises(RuntimeError) { LoggingFailureJob.perform_now }
      assert_equal "boom", error.message
    end

    assert_equal 2, entries.size
    assert_equal :info, entries[0][:level]
    assert_equal "ApplicationJobTest::LoggingFailureJob starting...", entries[0][:message]
    assert_equal "ApplicationJobTest::LoggingFailureJob", entries[0][:payload]["job_class"]
    assert entries[0][:payload]["job_id"].present?
    assert_equal :error, entries[1][:level]
    assert_equal "ApplicationJobTest::LoggingFailureJob failed: boom", entries[1][:message]
    assert_equal "ApplicationJobTest::LoggingFailureJob", entries[1][:payload]["job_class"]
    assert_equal "RuntimeError", entries[1][:payload]["error_class"]
    assert_equal "boom", entries[1][:payload]["error_message"]
  end

  private

  def capture_system_logger
    entries = []
    original_publish = SystemLogger.method(:publish)

    SystemLogger.singleton_class.define_method(:publish) do |payload|
      entries << {
        level: payload[:severity].to_sym,
        message: payload[:message],
        payload: payload[:payload]
      }
      true
    end

    yield
    entries
  ensure
    SystemLogger.singleton_class.define_method(:publish) do |payload|
      original_publish.call(payload)
    end if original_publish
  end
end
