module Characters
  class FactsComponent < SectionComponent
    delegate :datatable, to: :controller, allow_nil: true

    def initialize(character:, controller: nil, partner: nil, editable: false)
      super
      return unless controller

      controller.send(
        :load_datatable,
        datatable_class: Characters::FactsDatatableComponent,
        scope: facts_scope,
        character:,
        editable:,
        path: datatable_path
      )
    end

    def badge_count
      total_count
    end

    def datatable_frame_request?
      turbo_frame_request_id == datatable.frame_id
    end

    def results_frame_request?
      turbo_frame_request_id == datatable.results_frame_id
    end

    def section_icon_class
      "icon-[lucide--brain]"
    end

    def section_data
      {
        controller: "character-facts",
        character_facts_total_count_value: total_count,
        action: "datatable:before-refresh->character-facts#storeDrafts datatable:after-refresh->character-facts#restoreDrafts"
      }
    end

    def section_tab_badge_data
      { character_details_target: "factsCountBadge" }
    end

    def total_count
      character.facts.count
    end

    def visible?
      character.facts.any?
    end

    private

    def facts_scope
      character.facts.includes(:topic, :author)
    end

    def datatable_path
      controller.section_character_path(character)
    end
  end
end
