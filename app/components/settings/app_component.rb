module Settings
  class AppComponent < SectionComponent
    form_enabled true
    icon_class "icon-[lucide--settings]"

    private

    def protocol_options
      Setting::APP_PROTOCOLS
    end
  end
end
