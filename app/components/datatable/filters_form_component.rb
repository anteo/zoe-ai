module Datatable
  class FiltersFormComponent < ApplicationComponent
    attr_reader :datatable, :filters, :filter_component_class

    def initialize(datatable:, filters:, filter_component_class:)
      @datatable = datatable
      @filters = filters
      @filter_component_class = filter_component_class
    end

    def form_classes
      filter_component.form_classes
    end

    def hidden_filter_fields
      filters.preserved_attributes.to_a
    end

    def hidden_request_fields
      datatable.params.except("q", datatable.page_param.to_s).compact_blank
    end

    def render_filter_component(form)
      helpers.render filter_component_class.new(datatable:, filters:, form:)
    end

    private

    def filter_component
      @filter_component ||= filter_component_class.new(datatable:, filters:)
    end
  end
end
