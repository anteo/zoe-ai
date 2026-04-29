require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
# require "action_mailbox/engine"
# require "action_text/engine"
require "rails/test_unit/railtie"

require_relative "../lib/pragmatic_segmenter/languages/russian_with_emoji"
require "rainbow/refinement"
require "redcarpet"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Ai
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Asia/Novosibirsk"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Store files `locally.
    config.active_storage.service = :local

    config.i18n.available_locales = [ :en, :ru ] # Add all supported locales
    config.i18n.default_locale = :en

    config.active_job.queue_adapter = :solid_queue

    config.solid_queue.logger = ActiveSupport::Logger.new(STDOUT)

    if ENV["ZOE_APP__EXTRA_HOSTS"].present?
      config.hosts.push(*ENV["ZOE_APP__EXTRA_HOSTS"].split(","))
    end

    languages = PragmaticSegmenter::Languages
    languages::LANGUAGE_CODES["ru_emoji"] = languages::RussianWithEmoji
  end
end
