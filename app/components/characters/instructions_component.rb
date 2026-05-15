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
      { character_instructions_target: "countBadge" }
    end

    def visible?
      character.ai?
    end

    def existing_instructions_json
      character.instructions.active.ordered.map { { id: it.id, content: it.content } }.to_json
    end
  end
end
