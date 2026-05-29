module AI
  module Tools
    class ManageOwnInstructions < Tool
      description -> {
        partner_name = chat.partner.name
        <<~TEXT.squish
          View and manage #{partner_name}'s own character instructions for the current chat.
          This tool is limited to the current AI character only.
        TEXT
      }

      params do
        string :action,
               description: "Instruction action to perform",
               enum: %w[list add update remove],
               required: true

        integer :instruction_id,
                description: "Existing instruction ID to update or remove. Use IDs returned by list.",
                required: false

        string :content,
               description: "Instruction text to add or replace. Required for add and update.",
               required: false
      end

      def execute(action:, instruction_id: nil, content: nil)
        case action
        when "list"
          list_instructions
        when "add"
          require_writable_character!
          add_instruction!(content)
        when "update"
          require_writable_character!
          update_instruction!(instruction_id, content)
        when "remove"
          require_writable_character!
          remove_instruction!(instruction_id)
        else
          fail! "Unsupported action: #{action}"
        end
      end

      private

      def list_instructions
        instructions = scoped_instructions.to_a
        return "No character-specific instructions are set for #{chat.partner.name}." if instructions.empty?

        instructions.map do |instruction|
          %(#{instruction.id}: #{instruction.content})
        end.join("\n")
      end

      def add_instruction!(content)
        instruction = scoped_instructions.create!(
          active: true,
          content: normalized_content!(content)
        )

        %(Added instruction #{instruction.id} for #{chat.partner.name}: #{instruction.content})
      end

      def update_instruction!(instruction_id, content)
        instruction = find_instruction!(instruction_id)
        instruction.update!(
          active: true,
          content: normalized_content!(content)
        )

        %(Updated instruction #{instruction.id} for #{chat.partner.name}: #{instruction.content})
      end

      def remove_instruction!(instruction_id)
        instruction = find_instruction!(instruction_id)
        instruction.destroy!

        %(Removed instruction #{instruction.id} for #{chat.partner.name})
      end

      def scoped_instructions
        chat.partner.instructions.active.ordered
      end

      def find_instruction!(instruction_id)
        fail! "instruction_id is required for this action" if instruction_id.blank?

        scoped_instructions.find_by(id: instruction_id).tap do |instruction|
          fail! "Instruction not found: #{instruction_id}" unless instruction
        end
      end

      def normalized_content!(content)
        value = content.to_s.strip
        fail! "content is required for this action" if value.blank?

        value
      end

      def require_writable_character!
        return if chat.partner.owned_by?(current_user)

        fail! "#{chat.partner.name}'s instructions can only be changed by the character owner"
      end
    end
  end
end
