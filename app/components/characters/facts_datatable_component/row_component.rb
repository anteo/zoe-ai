module Characters
  class FactsDatatableComponent < Datatable::BaseComponent
    class RowComponent < Datatable::RowComponent
      def editable?
        datatable.editable
      end

      def fact
        record
      end

      def fact_date
        return unless fact.mentioned_at

        l(fact.mentioned_at.to_date)
      end

      def fact_kind_icon_class
        case fact.kind.to_s
        when "attribute"
          "icon-[lucide--id-card]"
        when "experience"
          "icon-[lucide--sparkles]"
        when "belief"
          "icon-[lucide--lightbulb]"
        when "preference"
          "icon-[lucide--heart]"
        when "plan"
          "icon-[lucide--map]"
        else
          "icon-[lucide--tag]"
        end
      end

      def fact_kind_label
        t(:"label_fact_kind_#{fact.kind}")
      rescue I18n::MissingTranslationData
        fact.kind.to_s.humanize
      end

      def fact_persistence_icon_class
        fact.persistent? ? "icon-[lucide--check]" : nil
      end

      def fact_time
        return unless fact.mentioned_at

        l(fact.mentioned_at, format: "%H:%M")
      end

      def fact_time_icon_class
        case fact.time
        when "past"
          "icon-[lucide--rewind]"
        when "future"
          "icon-[lucide--fast-forward]"
        else
          "icon-[lucide--play]"
        end
      end

      def fact_time_label
        case fact.time
        when "past"
          t(:label_time_past)
        when "future"
          t(:label_time_future)
        else
          t(:label_time_present)
        end
      end
    end
  end
end
