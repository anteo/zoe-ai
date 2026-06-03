module AI
  module Tools
    class GetChatHistory < Tool
      MAX_CHAT_COUNT = 20
      MAX_MESSAGES_PER_CHAT = 50
      DEFAULT_MESSAGES_PER_CHAT = 12

      description <<~TEXT.squish
        Retrieve closed conversation history for the current human/AI pair only.
        This tool can return summaries or recent visible transcript lines from closed non-dream chats.
      TEXT

      params do
        string :mode,
               description: "History lookup mode",
               enum: %w[last_n date_range],
               required: true
        string :pattern,
               description: "Optional case-insensitive regular expression to filter chats by summary or visible message content, for example word1|word2|word3",
               required: false
        integer :count,
                description: "Number of most recent chats to return when mode=last_n",
                required: false
        string :date_from,
               description: "Start date in YYYY-MM-DD when mode=date_range",
               required: false
        string :date_to,
               description: "End date in YYYY-MM-DD when mode=date_range. Defaults to date_from.",
               required: false
        boolean :include_summaries,
                description: "Whether to include chat summaries",
                required: false
        boolean :include_transcripts,
                description: "Whether to include visible transcript lines",
                required: false
        integer :max_messages_per_chat,
                description: "Maximum number of visible messages to return per chat when include_transcripts=true",
                required: false
      end

      def execute(mode:, pattern: nil, count: nil, date_from: nil, date_to: nil, include_summaries: true, include_transcripts: false,
                  max_messages_per_chat: DEFAULT_MESSAGES_PER_CHAT)
        chats = case mode
        when "last_n"
          fetch_last_n(count, pattern:)
        when "date_range"
          fetch_date_range(date_from:, date_to:, pattern:)
        else
          fail! "Unsupported mode: #{mode}"
        end

        JSON.generate(
          character_id: current_character.id,
          character_name: current_character.name,
          partner_id: chat.partner.id,
          partner_name: chat.partner.name,
          chats: chats.map do |history_chat|
            render_chat(
              history_chat,
              include_summaries:,
              include_transcripts:,
              max_messages_per_chat:
            )
          end
        )
      end

      private

      def base_scope
        current_user.chats
                    .closed
                    .dreaming(false)
                    .where(character: current_character, partner: chat.partner)
                    .where.not(closed_at: nil)
                    .order(closed_at: :desc, created_at: :desc, id: :desc)
      end

      def fetch_last_n(count, pattern:)
        value = count.to_i
        fail! "count must be between 1 and #{MAX_CHAT_COUNT}" unless value.between?(1, MAX_CHAT_COUNT)

        apply_pattern_filter(base_scope, pattern).limit(value).to_a
      end

      def fetch_date_range(date_from:, date_to:, pattern:)
        from = parse_date!(date_from, "date_from")
        to = date_to.present? ? parse_date!(date_to, "date_to") : from
        fail! "date_to must be on or after date_from" if to < from

        range = from.beginning_of_day..to.end_of_day
        apply_pattern_filter(base_scope.where(closed_at: range), pattern).to_a
      end

      def apply_pattern_filter(chats, pattern)
        return chats if pattern.blank?

        validate_pattern!(pattern)

        chats.where(
          <<~SQL.squish,
            chats.summary ~* :pattern OR EXISTS (
              SELECT 1
              FROM messages
              WHERE messages.chat_id = chats.id
                AND messages.role IN ('user', 'assistant', 'error')
                AND COALESCE(messages.content, '') <> ''
                AND messages.content ~* :pattern
            )
          SQL
          pattern:
        )
      end

      def parse_date!(value, name)
        fail! "#{name} is required for mode=date_range" if value.blank?

        Date.iso8601(value)
      rescue Date::Error
        fail! "#{name} must be in YYYY-MM-DD format"
      end

      def validate_pattern!(pattern)
        Regexp.new(pattern)
      rescue RegexpError
        fail! "pattern must be a valid regular expression"
      end

      def render_chat(history_chat, include_summaries:, include_transcripts:, max_messages_per_chat:)
        {
          chat_id: history_chat.id,
          created_at: history_chat.created_at.iso8601,
          closed_at: history_chat.closed_at&.iso8601,
          summary: include_summaries ? history_chat.summary.presence : nil,
          transcript: include_transcripts ? transcript_for(history_chat, max_messages_per_chat) : nil
        }
      end

      def transcript_for(history_chat, max_messages_per_chat)
        limit = max_messages_per_chat.to_i.clamp(1, MAX_MESSAGES_PER_CHAT)
        history_chat.messages
                    .visible
                    .order(:created_at, :id)
                    .last(limit)
                    .map(&:to_timestamp_message)
                    .join("\n")
      end
    end
  end
end
