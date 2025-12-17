module AI
  module Tools
    class Memory < Tool
      SIMILARITY_THRESHOLD = 0.85

      using Rainbow

      define_function :topic_search, description: "Recall the context of a conversation on a given topic." do
        property :query, type: "string", description: "Detailed question for searching memories", required: true
        property :name, type: "string", description: "Name of the character with whom the conversation took place", required: true
        property :detailed, type: "boolean", description: "Exact replicas requested (default: false)"
      end

      define_function :last_chat_search, description: "Recall previous conversation." do
        property :name, type: "string", description: "Name of the character with whom the conversation took place", required: true
        #property :detailed, type: "boolean", description: "exact replicas requested (default: false)"
      end

      def topic_search(query:, name:, detailed: false, limit: 10)
        # limit = detailed ? 5 : 10
        embedding = AI.embed("categorize_topic: #{query}").vectors
        person = find_person(name)
        lines = Line.by_person(person)
                    .where.not(chat_id: assistant.dialog)
                    .similar_to(embedding)
                    .select { _1.neighbor_time_distance < SIMILARITY_THRESHOLD }
                    .sort_by(&:neighbor_time_distance)
                    .take(limit)

        puts "Search for conversations about \"#{query}\" with #{person}:".faint
        result = process_chat_lines(lines:, character:, detailed:)
        puts result.faint.red
        result
      end

      def last_chat_search(name:, detailed: false)
        person = find_person(name)
        chat = ::Chat.by_character(person)
                   .preload(:lines)
                   .where.not(id: assistant.dialog)
                   .last

        fail! "Conversation not found" unless chat

        lines = chat.lines.to_a
        # detailed &&= lines.count < 10
        puts "Last conversation with #{person}:".faint
        result = detailed ? process_chat_lines(lines:, character:, detailed:) : chat.summary.to_s
        puts result.faint.red
        result
      end

      private

      def find_person(name)
        fail! "Can't use assistant's name" if name == assistant.ai.name
        person = ::Character.find_by(name:)
        fail! "Person with name #{name} not found" unless person
        person
      end

      def process_chat_lines(lines:, person:, detailed:)
        fail! "Nothing found" if lines.empty?

        if detailed
          lines.sort_by!(&:created_at)
          lines.map(&:to_timestamp_message).join("\n\n")
        else
          AI::Actors::SummarizeLines.call(lines:,
                                          initiator: person,
                                          companion: assistant.ai).summary
        end
      end
    end
  end
end