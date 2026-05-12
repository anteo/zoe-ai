require Rails.root.join("lib/simple_form/components/description")

SimpleForm.setup do |config|
  SimpleForm.include_component(SimpleForm::Components::Description)

  description_wrap = { class: "ml-1 mt-1 mb-1 border-l-2 border-base-300 pl-3 text-xs leading-6 text-base-content/45" }
  hint_wrap = { tag: :span, class: "ml-auto text-xs text-base-content/60 text-right" }
  error_wrap = { tag: :p, class: "validator-hint text-error text-xs leading-tight" }

  shared_components = lambda do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :minlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly
  end

  config.wrappers :daisy_input, tag: :div, class: "space-y-1", error_class: "has-error" do |b|
    shared_components.call(b)
    b.wrapper tag: :div, class: "flex items-center gap-2", unless_blank: true do |ba|
      ba.use :label, class: "label p-0 m-0"
      ba.use :hint, wrap_with: hint_wrap.dup
    end
    b.use :description, wrap_with: description_wrap.dup
    b.use :input, class: "input validator w-full", error_class: "input-error"
    b.use :error, wrap_with: error_wrap.dup
  end

  config.wrappers :daisy_textarea, tag: :div, class: "space-y-1", error_class: "has-error" do |b|
    shared_components.call(b)
    b.wrapper tag: :div, class: "flex items-center gap-2", unless_blank: true do |ba|
      ba.use :label, class: "label p-0 m-0"
      ba.use :hint, wrap_with: hint_wrap.dup
    end
    b.use :input, class: "textarea validator w-full", error_class: "textarea-error"
    b.use :error, wrap_with: error_wrap.dup
  end

  config.wrappers :daisy_select, tag: :div, class: "space-y-1", error_class: "has-error" do |b|
    shared_components.call(b)
    b.wrapper tag: :div, class: "flex items-center gap-2", unless_blank: true do |ba|
      ba.use :label, class: "label p-0 m-0"
      ba.use :hint, wrap_with: hint_wrap.dup
    end
    b.use :description, wrap_with: description_wrap.dup
    b.use :input, class: "select validator w-full", error_class: "select-error"
    b.use :error, wrap_with: error_wrap.dup
  end

  config.wrappers :daisy_boolean, tag: :div, class: "mt-1" do |b|
    b.use :html5
    b.optional :readonly
    b.wrapper tag: :div, class: "flex items-center gap-2", unless_blank: true do |ba|
      ba.wrapper tag: :label, class: "label cursor-pointer justify-start gap-3 p-0 m-0" do |bl|
        bl.use :input, class: "checkbox checkbox-sm"
        bl.use :label_text
      end
      ba.use :hint, wrap_with: hint_wrap.dup
    end
    b.use :description, wrap_with: description_wrap.dup
    b.use :error, wrap_with: error_wrap.dup
  end

  config.wrappers :autocomplete, tag: :div, class: "space-y-1", error_class: "has-error" do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :pattern
    b.optional :readonly

    b.wrapper tag: :div, class: "flex items-center gap-2", unless_blank: true do |ba|
      ba.use :label, class: "label p-0 m-0"
      ba.use :hint, wrap_with: hint_wrap.dup
    end
    b.use :description, wrap_with: description_wrap.dup

    b.use :input,
          class: "select select-bordered validator w-full cursor-text pr-10",
          error_class: "select-error",
          autocomplete_container_class: "relative w-full",
          autocomplete_results_class: "menu bg-base-100 rounded-box shadow-md absolute z-50 w-full mt-2 max-h-60 overflow-auto flex-nowrap border border-base-300"

    b.use :error, wrap_with: error_wrap.dup
  end

  config.default_wrapper = :daisy_input
  config.wrapper_mappings = {
    text: :daisy_textarea,
    file: :daisy_input,
    select: :daisy_select,
    autocomplete: :autocomplete,
    radio_buttons: :daisy_boolean,
    check_boxes: :daisy_boolean,
    boolean: :daisy_boolean
  }

  config.boolean_style = :inline
  config.boolean_label_class = nil
  config.button_class = "btn"
  config.error_notification_tag = :div
  config.error_notification_class = "alert alert-error text-sm"
  config.browser_validations = false
  config.generate_additional_classes_for = []
end
