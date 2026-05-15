module Settings
  class AIInstructionsComponent < SectionComponent
    form_enabled true
    form_scope "ai"
    icon_class "icon-[lucide--sparkles]"
    parent_section :ai

    def existing_instructions_json
      instructions.to_json
    end

    def instructions
      submitted = submitted_instructions
      return submitted unless submitted.nil?

      Instruction.global.active.ordered.map { { id: it.id, content: it.content } }
    end

    private

    def submitted_instructions
      raw_items = helpers.params.dig(form_object.model_name.param_key, "instructions_attributes")
      return unless raw_items.respond_to?(:values)

      raw_items.values.map do |item|
        {
          _destroy: item["_destroy"].to_s,
          id: item["id"].presence,
          content: item["content"].to_s
        }
      end
    end
  end
end
