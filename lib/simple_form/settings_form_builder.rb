module SimpleForm
  class SettingsFormBuilder < SimpleForm::FormBuilder
    def input(attribute_name, options = {}, &block)
      options = options.dup
      options[:input_html] ||= {}
      if object.try(:"#{attribute_name}_readonly?")
        options[:input_html].merge! disabled: true
        options[:hint] ||= I18n.t(:text_setting_env_override)
      end
      if (default = object.try(:"#{attribute_name}_default"))
        options[:placeholder] ||= default.to_s
        if object.try(attribute_name) == default
          options[:input_html][:value] ||= ""
        end
      end
      super(attribute_name, options, &block)
    end
  end
end
