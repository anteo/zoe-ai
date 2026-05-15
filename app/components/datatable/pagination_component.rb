module Datatable
  class PaginationComponent < ApplicationComponent
    GAP = :gap

    attr_reader :datatable, :pagy

    def initialize(pagy:, datatable:)
      @datatable = datatable
      @pagy = pagy
    end

    def visible?
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
