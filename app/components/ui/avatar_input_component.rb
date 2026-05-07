module UI
  class AvatarInputComponent < ApplicationComponent
    renders_one :fallback

    attr_reader :disabled, :form, :field, :icon_wrapper_class, :removable

    def initialize(form:, field: :avatar, icon_wrapper_class: "h-8 w-8",
                   removable: false, disabled: false)
      @disabled = disabled
      @form = form
      @field = field
      @icon_wrapper_class = icon_wrapper_class
      @removable = removable
    end

    def attachment_name
      "#{field}_attachment"
    end

    def attachment_record
      form.object.public_send(attachment_name) if form.object.respond_to?(attachment_name)
    end

    def can_remove?
      attachment_record.present?
    end

    def attachment_attributes_base
      "#{form.object_name}[#{attachment_name}_attributes]"
    end

    def attachment_id_field_name
      "#{attachment_attributes_base}[id]"
    end

    def attachment_destroy_field_name
      "#{attachment_attributes_base}[_destroy]"
    end

    def disabled?
      disabled
    end

  end
end
