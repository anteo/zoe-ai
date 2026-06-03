module AI
  module Tools
    class ManagePostponedMessages < Tool
      MessageSchema = RubyLLM::Schema.create do
        string :content,
               description: "Message text. Use an empty string only for attachment-only messages."
        array :attachment_ids,
              of: :integer,
              required: false,
              description: "Blob IDs to include in this postponed message. They may come from current-chat attachments or from attachment_ids returned by draw earlier in the same turn."
      end

      description -> {
        characters_json = JSON.generate(available_characters)

        <<~TEXT.squish
          View and manage postponed assistant messages authored by #{chat.partner.name} (character_id=#{chat.partner.id}).
          The queue is selected by target character_id. If omitted, use the current character #{current_character.name} (character_id=#{current_character.id}).
          Available target characters JSON: #{characters_json}
          Actions:
          - list: show postponed messages already queued for the selected character
          - add: queue one or more postponed messages for the selected character's next new chat
          - remove: delete postponed messages by IDs from the selected character's queue
          Attachment IDs may come from the current chat or from draw results generated earlier in the same turn.
        TEXT
      }

      params do
        string :action,
               description: "Queue action to perform",
               enum: %w[list add remove],
               required: true

        integer :character_id,
                description: "Target character ID from the available AI/human characters list. Omit to use the current character.",
                required: false

        array :messages,
              of: MessageSchema,
              description: "Messages to queue when action=add, in the order they should appear.",
              required: false

        array :pending_message_ids,
              of: :integer,
              description: "Pending message IDs to delete when action=remove. Use IDs returned by list.",
              required: false
      end

      def execute(action:, character_id: nil, messages: nil, pending_message_ids: nil)
        character = resolve_character!(character_id:)

        case action
        when "list"
          list_messages(character)
        when "add"
          add_messages(character, messages)
        when "remove"
          remove_messages(character, pending_message_ids)
        else
          fail! "Unsupported action: #{action}"
        end
      end

      private

      def queue_scope(character)
        PendingMessage.for_delivery(character:, author: chat.partner).with_attached_attachments
      end

      def list_messages(character)
        records = queue_scope(character).to_a
        JSON.generate(
          character_id: character.id,
          author_id: chat.partner.id,
          items: records.map do |record|
            {
              id: record.id,
              created_at: record.created_at.iso8601,
              content: record.content,
              attachment_ids: record.attachments.blobs.map(&:id),
              source_message_id: record.source_message_id
            }
          end
        )
      end

      def add_messages(character, messages)
        items = Array(messages)
        fail! "messages is required for action=add" if items.empty?

        blobs_by_message = items.map { blobs_for_message(it[:attachment_ids] || it["attachment_ids"]) }
        created_records = []

        PendingMessage.transaction do
          items.each_with_index do |message_params, index|
            content = message_params[:content] || message_params["content"]
            pending_message = PendingMessage.new(
              author: chat.partner,
              character: character,
              content:,
              source_message: source_message
            )
            pending_message.attachments.attach(blobs_by_message[index]) if blobs_by_message[index].any?
            pending_message.save!
            created_records << pending_message
          end
        end

        "Queued #{created_records.size} postponed message(s) for #{character.name} by #{chat.partner.name}"
      end

      def remove_messages(character, pending_message_ids)
        ids = Array(pending_message_ids).compact
        fail! "pending_message_ids is required for action=remove" if ids.empty?

        records = queue_scope(character).where(id: ids).to_a
        found_ids = records.map(&:id)
        missing_ids = ids - found_ids
        fail! "Pending message IDs not found in #{character.name}'s queue: #{missing_ids.join(', ')}" if missing_ids.any?

        PendingMessage.transaction do
          records.each(&:destroy!)
        end

        "Removed #{records.size} postponed message(s) from #{character.name}'s queue"
      end

      def resolve_character!(character_id:)
        return current_character if character_id.blank?

        available_characters_scope.find_by(id: character_id).tap do |character|
          fail! "Character not found: #{character_id}" unless character
        end
      end

      def blobs_for_message(attachment_ids)
        ids = Array(attachment_ids).compact
        return [] if ids.empty?

        chat_blobs = chat.attachments_blobs.where(id: ids).index_by(&:id)
        staged_blobs = chat.staged_attachment_blobs.index_by(&:id)
        blobs = staged_blobs.merge(chat_blobs)
        missing_ids = ids - blobs.keys
        fail! "Attachment IDs not found in current chat or staged draw results: #{missing_ids.join(', ')}" if missing_ids.any?

        blobs.values_at(*ids)
      end

      def available_characters_scope
        current_user.characters.where(third_party: false).order(:id)
      end

      def available_characters
        available_characters_scope.map do |character|
          {
            character_id: character.id,
            name: character.name,
            type: character.ai? ? "ai" : "human"
          }
        end
      end

      def source_message
        message = chat.message if chat.respond_to?(:message)
        message if message&.persisted?
      end
    end
  end
end
