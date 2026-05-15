module Characters
  class InstructionsComponent < SectionComponent
    def badge_count
      character.instructions.active.count
    end

    def section_icon_class
      "icon-[lucide--sparkles]"
    end

    def section_data
      { existing_instructions_json: existing_instructions_json }
    end

    def section_tab_badge_data
      { instructions_target: "countBadge" }
    end

    def visible?
      character.ai?
    end

    def existing_instructions_json
      instructions.to_json
    end

    def instructions
      character.instructions.active.ordered.map { { id: it.id, content: it.content } }
    end
  end
end
