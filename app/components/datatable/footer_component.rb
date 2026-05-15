module Datatable
  class FooterComponent < ApplicationComponent
    attr_reader :datatable, :pagy, :records

    def initialize(pagy:, records:, datatable:)
      @datatable = datatable
      @pagy = pagy
      @records = records
    end

    def results_count?
      pagy.count.positive?
    end

    def visible?
      results_count?
    end

    def summary_classes
      "text-sm opacity-70"
    end
  end
end
