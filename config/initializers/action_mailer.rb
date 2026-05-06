Rails.application.config.after_initialize do
  Setting.watch(:app, :mailer) do  # smtp changes bubble up to :mailer
    app_url_options = {
      host:     Setting.app.host,
      port:     Setting.app.port,
      protocol: Setting.app.protocol
    }

    Rails.application.config.x.app_url_options = app_url_options
    Rails.application.routes.default_url_options = app_url_options
    ActionMailer::Base.default_url_options = app_url_options

    mailer_from     = Setting.mailer.from     || "no-reply@#{Setting.app.host}"
    mailer_reply_to = Setting.mailer.reply_to || mailer_from
    ActionMailer::Base.default(from: mailer_from, reply_to: mailer_reply_to)
    Devise.mailer_sender = mailer_from

    ActionMailer::Base.delivery_method       = Rails.env.test? ? :test : :smtp
    ActionMailer::Base.perform_deliveries    = Setting.mailer.perform_deliveries
    ActionMailer::Base.raise_delivery_errors = Setting.mailer.raise_delivery_errors.nil? \
                                                 ? Rails.env.production?
                                                 : Setting.mailer.raise_delivery_errors

    smtp = Setting.mailer.smtp
    ActionMailer::Base.smtp_settings = {
      address:              smtp.address,
      port:                 smtp.port,
      domain:               smtp.domain || Setting.app.host,
      user_name:            smtp.username.presence,
      password:             smtp.password.presence,
      authentication:       smtp.authentication.presence&.to_sym,
      enable_starttls_auto: smtp.enable_starttls_auto
    }
  end
end
