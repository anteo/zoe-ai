module Datatable
  class FilterComponent < ApplicationComponent
    attr_reader :datatable, :filters, :form

    def initialize(datatable:, filters:, form: nil)
      @datatable = datatable
      @filters = filters
      @form = form
    end

    def form_classes
      "flex items-center gap-3"
    end
  end
end
