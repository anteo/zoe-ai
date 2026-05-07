module AI
  module Agents
    class ExtractFacts < BaseAgent
      agent_key :extract_facts
      inputs :chat
      temperature 0.1
      instructions topics: -> { Topic.order(:name) },
                   characters: -> { chat.user.characters.order(:name) }

      schema do
        array :facts do
          object do
            integer :character_id, required: false
            string :character_bio, required: false
            string :character_name
            string :fact
            string :kind, enum: %w[attribute experience belief preference plan]
            string :time, enum: %w[past present future]
            integer :importance, minimum: 0, maximum: 100
            boolean :persistent
            string :date_from, required: false
            string :date_to, required: false
            integer :topic_id, required: false
            string :topic_name
          end
        end
      end

      def initialize(chat:, **kwargs)
        super(inputs: { chat: }, **kwargs)
      end
    end
  end
end
