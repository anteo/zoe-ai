# frozen_string_literal: true

app_host = ENV.fetch("APP_HOST", "localhost")
app_port = ENV.fetch("APP_PORT", Rails.env.production? ? "443" : "3000").to_i
app_protocol = ENV.fetch("APP_PROTOCOL", Rails.env.production? ? "https" : "http")
app_url_options = { host: app_host, port: app_port, protocol: app_protocol }

default_delivery_method =
  if Rails.env.test?
    "test"
  elsif Rails.env.production?
    "smtp"
  else
    "file"
  end

delivery_method = ENV.fetch("ACTION_MAILER_DELIVERY_METHOD", default_delivery_method)

bool = ->(key, default) { ENV.fetch(key, default).to_s == "true" }

Rails.application.configure do
  config.x.app_url_options = app_url_options
  Rails.application.routes.default_url_options = app_url_options
  config.action_mailer.default_url_options = app_url_options

  mailer_from = ENV.fetch("ACTION_MAILER_FROM", "no-reply@#{app_host}")
  mailer_reply_to = ENV.fetch("ACTION_MAILER_REPLY_TO", mailer_from)

  config.action_mailer.default_options = {
    from: mailer_from,
    reply_to: mailer_reply_to
  }

  config.action_mailer.perform_deliveries = bool.call("ACTION_MAILER_PERFORM_DELIVERIES", "true")
  config.action_mailer.raise_delivery_errors = bool.call("ACTION_MAILER_RAISE_DELIVERY_ERRORS", Rails.env.production? ? "true" : "false")
  config.action_mailer.delivery_method = delivery_method.to_sym

  if delivery_method == "file"
    config.action_mailer.file_settings = {
      location: Rails.root.join(ENV.fetch("ACTION_MAILER_FILE_PATH", "tmp/mails"))
    }
  elsif delivery_method == "smtp"
    smtp_address = Rails.env.production? ? ENV.fetch("SMTP_ADDRESS") : ENV.fetch("SMTP_ADDRESS", "localhost")

    config.action_mailer.smtp_settings = {
      address: smtp_address,
      port: ENV.fetch("SMTP_PORT", Rails.env.production? ? "587" : "1025").to_i,
      domain: ENV.fetch("SMTP_DOMAIN", app_host),
      user_name: ENV["SMTP_USERNAME"].presence,
      password: ENV["SMTP_PASSWORD"].presence,
      authentication: ENV["SMTP_AUTHENTICATION"].presence&.to_sym,
      enable_starttls_auto: bool.call("SMTP_ENABLE_STARTTLS_AUTO", "true")
    }
  end
end
