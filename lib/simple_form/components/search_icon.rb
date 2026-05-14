module SimpleForm
  module Components
    module SearchIcon
      def search_icon(_wrapper_options = nil)
        template.content_tag(:span, "", class: "icon-[lucide--search] h-4 w-4 opacity-60")
      end
    end
  end
end
