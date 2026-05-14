module Settings
  class MCPServersFiltersComponent < ApplicationComponent
    class Model < Datatable::FiltersForm
      attribute :name_or_key_or_last_error_cont, :string

      normalizes :name_or_key_or_last_error_cont, with: ->(value) { value.to_s.strip.presence }
    end

    attr_reader :datatable, :filters

    def initialize(datatable:, filters:)
      @datatable = datatable
      @filters = filters
    end
  end
end
