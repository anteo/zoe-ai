module Settings
  class MailerComponent < SectionComponent
    form_enabled true
    icon_class "icon-[lucide--mail]"

    def authentication_options
      Setting::SMTP_AUTHENTICATION_METHODS
    end
  end
end
