# frozen_string_literal: true

module UI
  class ModalComponent < ApplicationComponent
    renders_one :title
    renders_one :footer

    attr_reader :close_button, :header, :padding

    def initialize(close_button: true,
                   header: true,
                   padding: true,
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
        "overflow-y-auto",
        @height.nil? ? "max-h-[75vh]" : @height,
        @main_classes,
        ("p-4 pt-2" if padding)
      )
    end

    def footer_classes
      helpers.class_names(
        "modal-action m-0 p-4",
        @footer_classes
      )
    end

    def box_classes
      helpers.class_names(
        "modal-box p-0",
        @width.nil? ? "max-w-5xl" : @width,
        @box_classes
      )
    end

    def referrer_frame_hidden_tag
      helpers.hidden_field_tag(:referrer_frame_id, helpers.params[:referrer_frame_id] || referrer_frame_id)
    end
  end
end
