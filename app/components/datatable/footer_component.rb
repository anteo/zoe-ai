module Datatable
  class FooterComponent < ApplicationComponent
    GAP = :gap

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
      results_count? || pagination?
    end

    def pagination?
      pagy.pages > 1
    end

    def page_url(page)
      datatable.url_for_params(datatable.params.merge(datatable.page_param.to_s => page))
    end

    def page_series
      pagy.send(:series)
    end

    def page_token?(item)
      item.is_a?(Integer)
    end

    def layout_classes
      "mt-2 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"
    end

    def nav_classes
      "join join-horizontal justify-end self-start sm:self-auto"
    end

    def page_button_classes(active: false, disabled: false)
      helpers.class_names(
        "join-item btn btn-sm",
        "btn-active" => active,
        "pointer-events-none border-transparent bg-transparent text-base-content/35 opacity-100 shadow-none" => disabled
      )
    end
  end
end
