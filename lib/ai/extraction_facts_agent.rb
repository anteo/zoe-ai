module AI
  class ExtractionFactsAgent < BaseAgent
    inputs :chat
    temperature 0.1
    instructions topics: -> { Topic.all }, characters: -> { Character.where(ai: false) }

    schema do
      array :facts do
        object do
          string :character_id, required: false
          string :character_name, required: false
          string :fact
          string :kind, enum: %w[attribute experience belief preference plan]
          string :time, enum: %w[past present future]
          integer :importance, minimum: 0, maximum: 100
          boolean :persistent
          string :date_from, required: false
          string :date_to, required: false
          string :topic_id, required: false
          string :topic_name, required: false
        end
      end
    end

    def initialize(chat:, **kwargs)
      super(inputs: { chat: }, **kwargs)
    end
  end
end
