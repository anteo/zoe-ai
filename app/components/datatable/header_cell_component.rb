module Datatable
  class HeaderCellComponent < ApplicationComponent
    attr_reader :header, :sort, :th_class

    def initialize(header:, sort: nil, th_class: nil)
      @header = header
      @sort = sort
      @th_class = th_class
    end

    def sortable?
      sort.present?
    end
  end
end
