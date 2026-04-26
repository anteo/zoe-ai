module AI
  module Tools
    class AddCharacterImage < Tool
      description "Add an image/photo for a character using an attachment from the current chat."

      params do
        integer :attachment_id,
                description: "Blob ID of the attachment to use (from the IDs listed in the message)",
                required: true

        string :description,
               description: "Short identity label using the person's actual name(s) and one key visible trait (e.g. 'Антон with kalimba', 'Нина in glasses'). Omit colors, clothing, background, and scene details.",
               required: false

        integer :character_id,
                description: "ID of the character to add image to, from the <characters> system prompt section",
                required: true
      end

      def execute(attachment_id:, character_id:, description: nil)
        character = current_user.characters.find_by(id: character_id)
        fail! "Character with ID #{character_id} not found" unless character

        blob = chat.attachments_blobs.find_by(id: attachment_id)
        fail! "Attachment with ID #{attachment_id} not found" unless blob

        blob.metadata[:description] = description
        character.images.attach(blob)

        "New image added for #{character.name}"
      end
    end
  end
end
