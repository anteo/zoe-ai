module AI
  module Tools
    class ManageOwnInstructions < Tool
      description -> {
        partner_name = chat.partner.name
        <<~TEXT.squish
          View and manage #{partner_name}'s own conversation or dreaming instructions.
          This tool is limited to the current AI character only. When dream=true it works with dreaming instructions,
          otherwise it works with conversation instructions. If dream is omitted, it defaults to the current chat mode.
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

        boolean :dream,
                description: "Whether to target dreaming instructions. Defaults to the current chat mode.",
                required: false

        string :content,
               description: "Instruction text to add or replace. Required for add and update.",
               required: false
      end

      def execute(action:, instruction_id: nil, dream: nil, content: nil)
        case action
        when "list"
          list_instructions(dream:)
        when "add"
          require_writable_character!
          add_instruction!(content, dream:)
        when "update"
          require_writable_character!
          update_instruction!(instruction_id, content, dream:)
        when "remove"
          require_writable_character!
          remove_instruction!(instruction_id, dream:)
        else
          fail! "Unsupported action: #{action}"
        end
      end

      private

      def list_instructions(dream:)
        instructions = scoped_instructions(dream:).to_a
        JSON.generate(
          character_id: chat.partner.id,
          dream: dream_mode?(dream),
          items: instructions.map do |instruction|
            {
              id: instruction.id,
              content: instruction.content
            }
          end
        )
      end

      def add_instruction!(content, dream:)
        instruction = scoped_instructions(dream:).create!(
          active: true,
          content: normalized_content!(content)
        )

        %(Added #{instruction_mode_name(dream)} instruction #{instruction.id} for #{chat.partner.name}: #{instruction.content})
      end

      def update_instruction!(instruction_id, content, dream:)
        instruction = find_instruction!(instruction_id, dream:)
        instruction.update!(
          active: true,
          content: normalized_content!(content)
        )

        %(Updated #{instruction_mode_name(dream)} instruction #{instruction.id} for #{chat.partner.name}: #{instruction.content})
      end

      def remove_instruction!(instruction_id, dream:)
        instruction = find_instruction!(instruction_id, dream:)
        instruction.destroy!

        %(Removed #{instruction_mode_name(dream)} instruction #{instruction.id} for #{chat.partner.name})
      end

      def scoped_instructions(dream:)
        chat.partner.instructions.where(dream: dream_mode?(dream)).active.ordered
      end

      def find_instruction!(instruction_id, dream:)
        fail! "instruction_id is required for this action" if instruction_id.blank?

        scoped_instructions(dream:).find_by(id: instruction_id).tap do |instruction|
          fail! "Instruction not found: #{instruction_id}" unless instruction
        end
      end

      def dream_mode?(dream)
        return chat.dream? if dream.nil?

        ActiveModel::Type::Boolean.new.cast(dream)
      end

      def instruction_mode_name(dream)
        dream_mode?(dream) ? "dreaming" : "conversation"
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
