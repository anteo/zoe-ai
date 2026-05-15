module Characters
  class FactsDatatableComponent < Datatable::BaseComponent
    class FiltersComponent < Datatable::FilterComponent
      class Model < Datatable::FiltersForm
        attribute :persistent, :string
        attribute :query, :string
        attribute :topic, :string

        normalizes :persistent, with: ->(value) { value.to_s == "all" ? nil : value.to_s.strip.presence }
        normalizes :query, :topic, with: ->(value) { value.to_s.strip.presence }

        def specific_ransack_params
          {
            content_or_author_name_or_topic_name_cont: query,
            persistent_eq: persistent,
            topic_name_eq: topic
          }.compact_blank
        end
      end

      def form_classes
        "grid gap-2 md:grid-cols-[minmax(0,2fr)_minmax(0,1fr)_minmax(0,1fr)]"
      end
    end
  end
end
