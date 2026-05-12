module Settings
  class AppComponent < SectionComponent
    private

    def protocol_options
      Setting::APP_PROTOCOLS
    end
  end
end
