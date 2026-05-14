module Settings
  class MailerComponent < SectionComponent
    def authentication_options
      Setting::SMTP_AUTHENTICATION_METHODS
    end
  end
end
