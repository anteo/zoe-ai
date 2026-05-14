module Datatable
  class FiltersComponent < ApplicationComponent
    attr_reader :datatable, :filters

    def initialize(datatable:, filters:, form_classes: "flex items-center gap-3")
      @datatable = datatable
      @filters = filters
      @form_classes = form_classes
    end

    def form_classes
      @form_classes
    end

    def hidden_filter_fields
      filters.preserved_attributes.to_a
    end

    def with_controls(&block)
      @controls_block = block
    end

    def controls?
      @controls_block.present?
    end

    def render_controls(form)
      helpers.capture(form, &@controls_block) if controls?
    end
  end
end
