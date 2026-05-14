module UI
  class SettingsComponent < ApplicationComponent
    SECTIONS = {
      "app" => {
        icon: "icon-[lucide--settings]",
        form: -> { Setting.app },
        scope: "app"
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
      "mcp_servers" => {
        icon: "icon-[lucide--server-cog]",
        parent: "ai"
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

    def section_component
      @section_component ||= section_component_class.new
    end

    def section_frame_id
      "settings__#{@section}".to_sym
    end

    def section_body
      helpers.turbo_frame_tag(section_frame_id) do
        render(section_component)
      end
    end

    def title
      I18n.t(:"label_settings_#{@section}")
    end

    def form?
      section_options[:form]
    end

    def with_optional_form(&block)
      if form?
        form_html = { class: "flex h-full min-h-0 flex-col overflow-hidden" }.merge(section_options[:html]&.call || {})
        helpers.simple_form_for section_options[:form].call,
                                url: settings_path(scope: section_options[:scope]),
                                method: :patch,
                                builder: SettingsFormBuilder,
                                html: form_html do |f|
          section_component.f = f
          helpers.capture(f, &block)
        end
      else
        helpers.capture(&block)
      end
    end

    private

    def section_component_class
      "Settings::#{@section.camelize}Component".constantize
    end
  end
end
