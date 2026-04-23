# frozen_string_literal: true

SimpleForm.setup do |config|
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
    b.wrapper tag: :div, class: "flex items-center gap-2" do |ba|
      ba.use :label, class: "label p-0 m-0"
      ba.use :hint, wrap_with: { tag: :span, class: "ml-auto text-xs text-base-content/60 text-right" }
    end
    b.use :input, class: "input w-full", error_class: "input-error"
    b.use :error, wrap_with: { tag: :p, class: "text-error text-xs leading-tight mt-0" }
  end

  config.wrappers :daisy_textarea, tag: :div, class: "space-y-1", error_class: "has-error" do |b|
    shared_components.call(b)
    b.wrapper tag: :div, class: "flex items-center gap-2" do |ba|
      ba.use :label, class: "label p-0 m-0"
      ba.use :hint, wrap_with: { tag: :span, class: "ml-auto text-xs text-base-content/60 text-right" }
    end
    b.use :input, class: "textarea w-full", error_class: "textarea-error"
    b.use :error, wrap_with: { tag: :p, class: "text-error text-xs leading-tight mt-0" }
  end

  config.wrappers :daisy_select, tag: :div, class: "space-y-1", error_class: "has-error" do |b|
    shared_components.call(b)
    b.wrapper tag: :div, class: "flex items-center gap-2" do |ba|
      ba.use :label, class: "label p-0 m-0"
      ba.use :hint, wrap_with: { tag: :span, class: "ml-auto text-xs text-base-content/60 text-right" }
    end
    b.use :input, class: "select w-full", error_class: "select-error"
    b.use :error, wrap_with: { tag: :p, class: "text-error text-xs leading-tight mt-0" }
  end

  config.wrappers :daisy_boolean, tag: :div, class: "mt-1" do |b|
    b.use :html5
    b.optional :readonly
    b.wrapper tag: :label, class: "label cursor-pointer justify-start gap-3" do |ba|
      ba.use :input, class: "checkbox checkbox-sm"
      ba.use :label_text
    end
    b.use :error, wrap_with: { tag: :p, class: "text-error text-xs mt-1" }
  end

  config.default_wrapper = :daisy_input
  config.wrapper_mappings = {
    text: :daisy_textarea,
    file: :daisy_input,
    select: :daisy_select,
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
