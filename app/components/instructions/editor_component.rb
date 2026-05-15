module Instructions
  class EditorComponent < ApplicationComponent
    attr_reader :editable, :empty_text, :field_name_prefix, :instructions

    def initialize(instructions:, field_name_prefix:, editable: false, empty_text: nil)
      @instructions = instructions
      @field_name_prefix = field_name_prefix
      @editable = editable
      @empty_text = empty_text || I18n.t(:text_no_character_instructions)
    end

    def field_name(attribute)
      "#{field_name_prefix}[__INDEX__][#{attribute}]"
    end
  end
end
