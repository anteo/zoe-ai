module Characters
  class DreamsComponent < SectionComponent
    def section_icon_class
      "icon-[lucide--moon-star]"
    end

    def section_data
      { existing_instructions_json: existing_instructions_json }
    end

    def visible?
      character.ai? && character.dreaming_enabled?
    end

    def existing_instructions_json
      instructions.to_json
    end

    def instructions
      character.dreaming_instructions.active.ordered.map { { id: it.id, content: it.content } }
    end
  end
end
