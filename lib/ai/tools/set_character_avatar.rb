module AI
  module Tools
    class SetCharacterAvatar < Tool
      description <<~END
        Add an avatar for a character using an attachment from the current chat
        (use only if user explicitly said to set his avatar)"
      END
      params do
        characters = ::Character.all.map { |c| "#{c.id} (#{c.name})" }.join(", ")

        integer :attachment_id,
                description: "Blob ID of the attachment to use as the avatar (from the IDs listed in the message)",
                required: true

        string :character_id,
               description: "ID of the character to add image to. Available: #{characters}",
               enum: ::Character.pluck(:id).map(&:to_s),
               required: true
      end

      def execute(attachment_id:, character_id:)
        character = current_user.characters.find_by(id: character_id)
        fail! "Character with ID #{character_id} not found" unless character

        blob = chat.attachments_blobs.find_by(id: attachment_id)
        fail! "Attachment with ID #{attachment_id} not found" unless blob

        character.avatar.attach(blob)

        "New avatar added for #{character.name}"
      end
    end
  end
end
