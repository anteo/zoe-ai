module Datatable
  class ResultsComponent < ApplicationComponent
    attr_reader :datatable

    delegate :body_id, :empty?, :empty_state_classes, :empty_state_i18n_key, :footer_component,
             :header_component, :records, :row_component, :table_classes, :table_wrapper_classes, to: :datatable

    def initialize(datatable:)
      @datatable = datatable
    end
  end
end
