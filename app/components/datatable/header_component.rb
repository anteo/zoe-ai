module Datatable
  class HeaderComponent < ApplicationComponent
    attr_reader :datatable, :search

    def initialize(search:, datatable:)
      @datatable = datatable
      @search = search
    end

    def sort_active?(attribute)
      sort_direction_for(attribute).present?
    end

    def sort_classes(attribute)
      helpers.class_names("link link-hover inline-flex items-center gap-1", "font-semibold" => sort_active?(attribute))
    end

    def sort_direction_for(attribute)
      current_sort(attribute)&.dir&.downcase
    end

    def sort_indicator_icon_class(attribute)
      case sort_direction_for(attribute)
      when "asc" then "icon-[lucide--arrow-up]"
      when "desc" then "icon-[lucide--arrow-down]"
      else "icon-[lucide--arrow-up-down]"
      end
    end

    private

    def current_sort(attribute)
      search.sorts.detect { |sort| sort.name == attribute.to_s }
    end
  end
end
