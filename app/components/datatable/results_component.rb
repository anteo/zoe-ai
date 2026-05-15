module Datatable
  class ResultsComponent < ApplicationComponent
    attr_reader :datatable

    delegate :body_id, :empty?, :empty_state_classes, :empty_state_i18n_key, :footer_component,
             :header_component, :pagination_bottom?, :pagination_component, :pagination_top?,
             :records, :row_component, :table_classes,
             :table_wrapper_classes, to: :datatable

    def initialize(datatable:)
      @datatable = datatable
    end

    def bottom_layout_classes
      "mt-2 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"
    end

    def top_pagination_classes
      "mb-2 flex justify-end"
    end

    def top_pagination_visible?
      pagination_top? && pagination_component.visible?
    end

    def bottom_pagination_visible?
      pagination_bottom? && pagination_component.visible?
    end

    def bottom_section_visible?
      footer_component.visible? || bottom_pagination_visible?
    end

    def bottom_spacer_visible?
      footer_component.visible? && bottom_pagination_visible?
    end

    def bottom_spacer_classes
      "hidden sm:block"
    end
  end
end
