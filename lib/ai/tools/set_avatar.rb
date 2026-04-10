module AI
  module Tools
    class SetAvatar < Tool
      description "Set an avatar photo for a character using an attachment from the current chat."

      params do
        integer :attachment_id, description: "Blob ID of the attachment to use as the avatar (from the IDs listed in the message)", required: true
        integer :character_id, description: "ID of the character to set the avatar for", required: true
      end

      def params_schema
        schema = super.deep_dup
        characters = ::Character.all.map { |c| "#{c.id} (#{c.name})" }.join(", ")
        schema["properties"]["character_id"]["enum"] = ::Character.pluck(:id)
        schema["properties"]["character_id"]["description"] = "ID of the character to set the avatar for. Available: #{characters}"
        schema
      end

      def execute(attachment_id:, character_id:)
        character = ::Character.find_by(id: character_id)
        fail! "Character with ID #{character_id} not found" unless character

        blob = ActiveStorage::Blob.find_by(id: attachment_id)
        fail! "Attachment with ID #{attachment_id} not found" unless blob

        character.avatar.attach(blob)
        "Avatar set for #{character.name}"
      end
    end
  end
end
