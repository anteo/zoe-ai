module UI
  class SettingsComponent < ApplicationComponent
    SECTIONS = {
      "app" => {
        icon: "icon-[lucide--settings]",
        form: -> { Setting.app },
        scope: "app"
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
        icon: "icon-[lucide--mail]",
        form: -> { Setting.mailer },
        scope: "mailer"
      },
      "ui" => {
        icon: "icon-[lucide--monitor]",
        form: -> { Setting.ui },
      },
      "events" => {
        icon: "icon-[lucide--history]",
        form: -> { Setting.events },
        scope: "events"
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

    def section_component(f)
      @section_components ||= {}
      @section_components[f.object_name] ||= section_component_class.new(f:)
    end

    private

    def section_component_class
      "Settings::#{@section.camelize}Component".constantize
    end
  end
end
