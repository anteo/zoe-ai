module Settings
  class BodyComponent < ApplicationComponent
    SECTIONS = {
      "app" => {
        icon: "icon-[lucide--settings]"
      },
      "ai" => {
        icon: "icon-[lucide--sparkles]",
        form: -> { Setting.ai },
        scope: "ai",
      },
      "providers" => {
        icon: "icon-[lucide--plug]",
        form: -> { Setting.ai },
        scope: "ai",
        show_apply: true,
        show_save: false,
        html: lambda {
          {
            data: {
              controller: "admin-console-opener",
              action: "submit->admin-console-opener#open",
              admin_console_opener_admin_console_modal_outlet: "#admin-console-modal"
            }
          }
        }
      },
      "mailer" => {
        icon: "icon-[lucide--mail]"
      },
      "ui" => {
        icon: "icon-[lucide--monitor]"
      },
      "events" => {
        icon: "icon-[lucide--history]"
      }
    }.freeze

    def initialize(section: nil)
      @section = SECTIONS.key?(section.to_s) ? section.to_s : SECTIONS.keys.first
    end

    def active?(key)
      @section == key
    end

    def section_options = SECTIONS.fetch(@section)
  end
end
