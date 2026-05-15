module Characters
  class DetailsComponent < ApplicationComponent
    SECTIONS = %i[memory_profile events instructions facts images].freeze

    attr_reader :character, :partner

    def initialize(character:, partner:, controller:)
      @character = character
      @partner = partner
      @controller = controller
    end

    def type_label
      if character.ai?
        t(:label_ai)
      elsif character.third_party?
        t(:label_other)
      else
        t(:label_human)
      end
    end

    def type_badge_class
      if character.ai?
        "badge-primary"
      elsif character.third_party?
        "badge-neutral"
      else
        "badge-warning"
      end
    end

    def deletable?
      character.detachable_by?(helpers.current_user)
    end

    def editable?
      character.editable_by?(helpers.current_user)
    end

    def owned?
      character.owned_by?(helpers.current_user)
    end

    def shared?
      !owned?
    end

    def shareable?
      character.shareable_by?(helpers.current_user)
    end

    def destroy_confirm_text
      owned? ? t(:confirm_delete_character) : t(:confirm_unshare_character)
    end

    def destroy_title
      owned? ? t(:label_delete) : t(:label_unshare_character)
    end

    def section_components
      SECTIONS.map { component_class(:"characters__#{it}") }
    end

    def sections
      @sections ||= section_components.filter_map do |component_class|
        component = component_class.new(character:, partner:, controller:, editable: editable?)
        component if component.visible?
      end
    end

    def default_section
      sections.first.section_key
    end
  end
end
