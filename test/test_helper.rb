ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  parallelize(workers: 1)
  self.use_transactional_tests = true

  include ActiveSupport::Testing::TimeHelpers
end
