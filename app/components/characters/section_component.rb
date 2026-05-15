module Characters
  class SectionComponent < ApplicationComponent
    attr_reader :character, :controller, :editable, :partner

    def initialize(character:, controller: nil, partner: nil, editable: false)
      @character = character
      @controller = controller
      @editable = editable
      @partner = partner
    end

    def badge_count
      nil
    end

    def section_frame_id
      "character-section-#{section_key}"
    end

    def section_icon_class
      nil
    end

    def section_label
      I18n.t(:"label_#{section_key}")
    end

    def section_panel_classes(active:)
      [
        active ? "block" : "hidden",
      ].join(" ")
    end

    def section_path
      controller.section_character_path(character, section: section_key)
    end

    def section_attributes
      {}.tap do |attributes|
        attributes[:class] = section_classes if section_classes.present?
        attributes[:data] = section_data if section_data.present?
      end
    end

    def section_tab_badge_data
      {}
    end

    def section_frame_request?
      turbo_frame_request_id == section_frame_id
    end

    def section_classes
      nil
    end

    def section_data
      {}
    end

    def visible?
      true
    end

    def turbo_frame_request_id
      controller&.send(:turbo_frame_request_id)
    end

    def section_key
      self.class.name.demodulize.delete_suffix("Component").underscore
    end
  end
end
