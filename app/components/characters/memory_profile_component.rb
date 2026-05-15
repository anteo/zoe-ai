module Characters
  class MemoryProfileComponent < SectionComponent
    def description
      @description ||= AI::Actors::DescribeCharacter.result(character:, partner:, mode: :markdown, period_order: :desc).description.to_s
    end

    def section_icon_class
      "icon-[lucide--file-text]"
    end

    def visible?
      description.present?
    end
  end
end
