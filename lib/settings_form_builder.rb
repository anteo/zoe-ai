class SettingsFormBuilder < SimpleForm::FormBuilder
  def input(attribute_name, options = {}, &block)
    options = options.dup
    options[:input_html] ||= {}
    if object.try(:"#{attribute_name}_readonly?")
      options[:input_html].merge! disabled: true
      options[:hint] ||= readonly_hint
    end
    if (default = object.try(:"#{attribute_name}_default"))
      options[:placeholder] ||= default.to_s
      if object.try(attribute_name) == default
        options[:input_html][:value] ||= ""
      end
    end
    super(attribute_name, options, &block)
  end

  private

  def readonly_hint
    @template.content_tag(:div,
                          class: "tooltip tooltip-left cursor-help",
                          data: { tip: I18n.t(:text_setting_env_override) }) do
      @template.content_tag(:span,
                            "",
                            class: "icon-[lucide--lock-keyhole] inline-block h-4 w-4 text-base-content/60",
                            aria: { hidden: true }) +
        @template.content_tag(:span, I18n.t(:text_setting_env_override_short), class: "sr-only")
    end
  end
end
