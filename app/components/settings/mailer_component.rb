module Settings
  class MailerComponent < SectionComponent
    private

    def authentication_options
      Setting::SMTP_AUTHENTICATION_METHODS
    end

    def before_render
      with_footer do
        f.button :submit, helpers.t(:label_test_smtp), name: "test_smtp", class: "btn btn-outline"
      end
    end
  end
end
