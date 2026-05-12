module SimpleForm
  module Components
    module Description
      def description(wrapper_options = nil)
        text = description_text
        return if text.blank?

        template.content_tag(:p, text, **wrapper_options.to_h)
      end

      def has_description?
        description_text.present?
      end

      private

      def description_text
        options[:description].presence || translated_description
      end

      def translated_description
        return unless object.class.respond_to?(:scope_path)

        scope_path = object.class.scope_path.presence
        return unless scope_path

        key = "descriptions.#{scope_path}.#{attribute_name}"
        translated = I18n.t(key, default: "")
        translated.presence
      end
    end
  end
end
