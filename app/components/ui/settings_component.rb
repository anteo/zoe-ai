module UI
  class SettingsComponent < ApplicationComponent
    SECTIONS = {
      "app" => {
        icon: "icon-[lucide--settings]"
      },
      "ai" => {
        icon: "icon-[lucide--sparkles]",
        form: -> { Setting.ai },
        scope: "ai"
      },
      "ai_models" => {
        icon: "icon-[lucide--bot]",
        parent: "ai",
        form: -> { Setting.ai.models },
        scope: "ai.models"
      },
      "ai_providers" => {
        icon: "icon-[lucide--plug]",
        parent: "ai",
        form: -> { Setting.ai.providers },
        scope: "ai.providers",
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

    def top_level_sections
      SECTIONS.select { |_key, opts| opts[:parent].blank? }
    end

    def child_sections(parent_key)
      SECTIONS.select { |_key, opts| opts[:parent] == parent_key }
    end

    def section_options = SECTIONS.fetch(@section)
  end
end
