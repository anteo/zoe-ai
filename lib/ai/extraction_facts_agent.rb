module AI
  class ExtractionFactsAgent < BaseAgent
    inputs :chat
    temperature 0.1
    instructions topics: -> { Topic.order(:name) },
                 characters: -> { chat.user.characters.order(:name) }

    schema do
      array :facts do
        object do
          integer :character_id, required: false, description: "ID of an existing known character this fact is about (preferred over character_name)"
          string :character_name, required: false, description: "Name of the person/pet this fact is about, if not in the known characters list (will create a new third-party character)"
          string :fact, description: "3rd-person description; replace pronouns with real names; translate to English, but keep Russian personal names in the nominative case, do not translate Russian personal names"
          string :kind, enum: %w[attribute experience belief preference plan]
          string :time, enum: %w[past present future]
          integer :importance, minimum: 0, maximum: 100, description: "Importance for personality description"
          boolean :persistent, description: "false for specific events or single-instance opinions (\"went shopping yesterday\", \"liked this painting\"); true for enduring traits, general habits, long‑term roles (\"likes painting\", \"is a student\", \"has a cat\")"
          string :date_from, required: false, description: "event date range start in YYYY-MM-DD if determinable"
          string :date_to, required: false, description: "event date range end in YYYY-MM-DD if determinable"
          integer :topic_id, required: false, description: "ID of an existing matching topic (preferred over topic_name)"
          string :topic_name, required: false, description: "New topic name if no existing topic matches"
        end
      end
    end

    def initialize(chat:, **kwargs)
      super(inputs: { chat: }, **kwargs)
    end
  end
end
