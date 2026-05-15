module UI
  class SettingsComponent < ApplicationComponent
    SECTIONS = %i[app mailer ui events ai ai_models ai_providers agents mcp_servers].freeze

    def initialize(section: nil)
      @section = section_keys.include?(section.to_s) ? section.to_s : section_keys.first
    end

    def active?(key)
      @section == key.to_s
    end

    def top_level_sections
      section_components.select { it.parent_section.blank? }
    end

    def child_sections(parent_key)
      section_components.select { it.parent_section == parent_key.to_s }
    end

    def section_component
      @section_component ||= section_component_class.new
    end

    def section_icon_class
      section_component.section_icon_class
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
      section_component.section_label
    end

    def with_optional_form(&block)
      if section_component.form?
        form_html = { class: "flex h-full min-h-0 flex-col overflow-hidden" }.merge(section_component.form_html_options)
        helpers.simple_form_for section_component.form_object,
                                url: settings_path(scope: section_component.form_scope),
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

    def section_components
      @section_components ||= SECTIONS.map { |section| component_instance(:"settings__#{section}") }
    end

    def section_component_class
      "Settings::#{@section.camelize}Component".constantize
    end

    def section_keys
      @section_keys ||= SECTIONS.map(&:to_s)
    end
  end
end
