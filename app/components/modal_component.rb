# frozen_string_literal: true

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
                 width: "max-w-5xl",
                 box_classes: nil)

    @close_button = close_button
    @header = header
    @padding = padding
    @width = width
    @box_classes = box_classes
    @header_classes = header_classes
    @title_classes = title_classes
    @main_classes = main_classes
    @footer_classes = footer_classes
  end

  def before_render
    @width = helpers.class_names(@width.presence || "max-w-5xl")
    @box_classes = helpers.class_names(@box_classes)
    @header_classes = helpers.class_names(header_classes)
    @title_classes = helpers.class_names(title_classes)
    @main_classes = helpers.class_names(main_classes)
    @footer_classes = helpers.class_names(footer_classes)
  end

  def modal_frame_request?
    helpers.turbo_modal_frame?
  end

  def header_classes
    [
      "flex justify-between items-center w-full px-4 py-4 rounded-t-box",
      @header_classes
    ].compact.join(" ")
  end

  def title_classes
    [
      "text-lg font-bold",
      ("hidden" unless title?),
      @title_classes
    ].compact.join(" ")
  end

  def main_classes
    classes = [ "overflow-y-auto max-h-[75vh]", @main_classes ]
    classes << "p-4 pt-2" if padding
    classes.join(" ")
  end

  def footer_classes
    classes = [ "modal-action m-0 p-4", @footer_classes ]
    classes.join(" ")
  end

  def box_classes
    [ "modal-box p-0", @width, @box_classes ].compact.join(" ")
  end
end
