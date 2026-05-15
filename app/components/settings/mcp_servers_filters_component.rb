module Settings
  class MCPServersFiltersComponent < Datatable::FilterComponent
    class Model < Datatable::FiltersForm
      attribute :name_or_key_or_last_error_cont, :string

      normalizes :name_or_key_or_last_error_cont, with: ->(value) { value.to_s.strip.presence }
    end
  end
end
