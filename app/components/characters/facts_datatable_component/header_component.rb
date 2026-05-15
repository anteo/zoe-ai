module Characters
  class FactsDatatableComponent < Datatable::BaseComponent
    class HeaderComponent < Datatable::HeaderComponent
      def editable?
        datatable.editable
      end

      def icon_cell_class
        "w-1 text-center"
      end

      def text_header_class
        "min-w-[18rem] text-left"
      end
    end
  end
end
