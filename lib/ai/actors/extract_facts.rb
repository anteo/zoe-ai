module AI::Actors
  class ExtractFacts < Actor
    input :chat, type: Chat
    input :force, type: [ TrueClass, FalseClass ], default: false
    input :logger, default: -> { Rails.logger }

    fail_on RubyLLM::Error,
            ActiveRecord::RecordInvalid

    def current_user
      chat.user
    end

    def call
      if force
        chat.messages.update_all facts_extracted: false
        chat.facts.delete_all
      end
      logger.debug ">>> #{llm_chat.instructions}"
      messages = chat.messages
                     .visible
                     .preload(:character, facts: [ :character, :topic ])
                     .order(:created_at)
      messages.each do |message|
        if message.facts_extracted
          llm_chat.add_message(role: :user, content: message.to_direct_speech)
          llm_chat.add_message(role: :assistant, content: message.facts.map(&:to_h).to_json)
        elsif !message.memorize
          llm_chat.add_message(role: :user, content: message.to_direct_speech)
          llm_chat.add_message(role: :assistant, content: "[]")
          message.update_column :facts_extracted, true
        else
          extract_facts(message)
          sleep(1)
        end
      end
      chat.update_column :facts_extracted, true
    end

    private

    def extract_facts(message)
      content = message.to_direct_speech
      llm_chat.add_message(role: :user, content: content)
      logger.debug ">>> #{content}"
      response = llm_chat.complete
      facts = if response.content.is_a?(Array)
        response.content
      elsif response.content.is_a?(Hash) && response.content.key?("facts")
        response.content["facts"]
      else
        fail! message: "Malformed response", response: response.content
      end
      logger.debug "<<< #{facts.inspect}"
      facts.each do |fact_data|
        build_fact(fact_data, message).save!
      end
      message.update_column :facts_extracted, true
    rescue JSON::ParserError
      nil
    end

    def build_fact(data, message)
      Fact.new(
        character: resolve_character(data),
        author: message.character,
        content: data["fact"],
        kind: data["kind"],
        persistent: data["persistent"],
        time: data["time"],
        date_from: data["date_from"],
        date_to: data["date_to"],
        importance: data["importance"],
        mentioned_at: message.created_at,
        chat:,
        message:,
        topic: resolve_topic(data)
      )
    end

    def resolve_character(data)
      name = data["character_name"].presence
      character_id = data["character_id"].presence

      if character_id
        character = current_user.characters.find_by(id: character_id)
        # Only use the found character if name matches or is absent — the LLM sometimes
        # hallucinates a character_id from the known list while meaning a different person.
        return character if character && (name.nil? || character.name == name)
      end

      return unless name

      current_user.characters.find_or_create_by(name:) do |c|
        c.third_party = true
        c.description = ""
      end
    end

    def resolve_topic(data)
      if data["topic_id"].present?
        Topic.find_by(id: data["topic_id"])
      elsif data["topic_name"].present?
        Topic.find_or_create_by(name: data["topic_name"])
      end
    end

    def llm_chat
      @llm_chat ||= AI::ExtractionFactsAgent.chat(chat:)
    end
  end
end
