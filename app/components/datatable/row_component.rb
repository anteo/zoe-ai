module Datatable
  class RowComponent < ApplicationComponent
    attr_reader :datatable, :record

    def initialize(record:, datatable: nil)
      @datatable = datatable
      @record = record
    end

    def row_id
      datatable&.row_dom_id(record) || ActionView::RecordIdentifier.dom_id(record)
    end

    def action_button(path, label_key:, icon_class:, method:, button_class:, form_data: {})
      tooltip_action(label_key) do
        helpers.button_to path, method:, class: button_class, form: { data: form_data } do
          action_icon(icon_class, label_key)
        end
      end
    end

    def action_link(path, label_key:, icon_class:, link_class:, data: {})
      tooltip_action(label_key) do
        helpers.link_to path, class: link_class, data: data do
          action_icon(icon_class, label_key)
        end
      end
    end

    def loading_action_button
      helpers.button_tag type: "button", class: "btn btn-ghost btn-xs btn-square", disabled: true do
        helpers.tag.span(class: "loading loading-spinner loading-xs")
      end
    end

    private

    def action_icon(icon_class, label_key)
      helpers.safe_join([
        helpers.tag.span(class: "#{icon_class} h-4 w-4"),
        helpers.content_tag(:span, t(label_key), class: "sr-only")
      ])
    end

    def tooltip_action(label_key, &block)
      helpers.content_tag(:div, class: "tooltip tooltip-left", data: { tip: t(label_key) }, &block)
    end
  end
end
