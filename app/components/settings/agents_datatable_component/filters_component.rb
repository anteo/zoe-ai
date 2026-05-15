module Settings
  class AgentsDatatableComponent < Datatable::BaseComponent
    class FiltersComponent < Datatable::FilterComponent
      class Model < Datatable::FiltersForm
        attribute :name_or_key_cont, :string

        normalizes :name_or_key_cont, with: ->(value) { value.to_s.strip.presence }
      end
    end
  end
end
