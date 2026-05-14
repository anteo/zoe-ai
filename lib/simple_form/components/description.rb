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
        translated = if object.class.respond_to?(:scope_path) && object.class.scope_path.present?
          I18n.t("simple_form.descriptions.#{object.class.scope_path}.#{attribute_name}", default: "")
        elsif respond_to?(:translate_from_namespace, true)
          translate_from_namespace(:descriptions)
        end

        translated.presence
      end
    end
  end
end
