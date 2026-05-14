module UI
  class ModalComponent < ApplicationComponent
    renders_one :title
    renders_one :footer

    attr_reader :close_button, :header, :padding, :background

    def initialize(close_button: true,
                   header: true,
                   padding: true,
                   background: true,
                   header_classes: nil,
                   title_classes: nil,
                   main_classes: nil,
                   footer_classes: nil,
                   width: nil,
                   height: nil,
                   box_classes: nil,
                   frame_id: nil)

      @close_button = close_button
      @header = header
      @padding = padding
      @background = background
      @width = width
      @height = height
      @box_classes = box_classes
      @header_classes = header_classes
      @title_classes = title_classes
      @main_classes = main_classes
      @footer_classes = footer_classes
      @frame_id = frame_id
    end

    def update_existing?
      helpers.turbo_frame_request? && !helpers.request.get?
    end

    def referrer_frame_id
      @referrer_frame_id ||= update_existing? ? helpers.params[:referrer_frame_id] : helpers.turbo_frame_request_id
    end

    def frame_id
      @frame_id ||= update_existing? ? helpers.turbo_frame_request_id : "modal-#{SecureRandom.hex(6)}"
    end

    def header_classes
      helpers.class_names(
        "flex justify-between items-center w-full px-4 py-4 rounded-t-box",
        ("border-base-300 border-b" if background),
        @header_classes
      )
    end

    def title_classes
      helpers.class_names(
        "text-lg font-bold",
        ("hidden" unless title?),
        @title_classes
      )
    end

    def main_classes
      helpers.class_names(
        "flex-1 min-h-0 overflow-y-auto",
        @height,
        @main_classes,
        ("bg-base-200" if background),
        ("p-4" if padding)
      )
    end

    def footer_classes
      helpers.class_names(
        "modal-action m-0 shrink-0 p-4",
        ("border-base-300 border-t" if background),
        @footer_classes
      )
    end

    def box_classes
      helpers.class_names(
        "modal-box flex max-h-[calc(100dvh-2rem)] flex-col p-0",
        @width.nil? ? "max-w-5xl" : @width,
        @box_classes
      )
    end

    def referrer_frame_hidden_tag
      helpers.hidden_field_tag(:referrer_frame_id, helpers.params[:referrer_frame_id] || referrer_frame_id)
    end

    def alerts_dom_id
      helpers.modal_alerts_dom_id(frame_id)
    end
  end
end
