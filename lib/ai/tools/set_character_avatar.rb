module AI
  module Tools
    class SetCharacterAvatar < Tool
      description <<~END
        Add an avatar for a current user using an attachment from the current chat
        (use only if user explicitly said to set his avatar)"
      END
      params do
        integer :attachment_id,
                description: "Blob ID of the attachment to use as the avatar (from the IDs listed in the message)",
                required: true
      end

      def execute(attachment_id:)
        blob = chat.attachments_blobs.find_by(id: attachment_id)
        fail! "Attachment with ID #{attachment_id} not found" unless blob

        current_character.avatar.attach(blob)

        "New avatar added for #{current_character.name}"
      end
    end
  end
end
