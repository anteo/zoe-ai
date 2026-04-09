module AI::Actors
  class ExtractFacts < Actor
    input :chat, type: Chat
    input :debug, type: [ TrueClass, FalseClass ], default: false
    input :logger, default: -> { Rails.logger }

    fail_on RubyLLM::Error

    def call
      logger.info ">>> #{llm_chat.instructions}" if debug
      messages = chat.messages
                     .visible
                     .preload(:character, facts: [ :character, :topic ])
                     .order(:created_at)
      messages.each do |message|
        if message.facts_extracted
          llm_chat.add_message(role: :user, content: message.to_direct_speech)
          llm_chat.add_message(role: :assistant, content: message.facts.map(&:to_h).to_json)
        else
          extract_facts(message)
          sleep(5)
        end
      end
      chat.update_column :facts_extracted, true
    end

    private

    def extract_facts(message)
      content = message.to_direct_speech
      llm_chat.add_message(role: :user, content: content)
      response = llm_chat.complete
      facts = if response.content.is_a?(Array)
        response.content
      elsif response.content.is_a?(Hash) && response.content.key?("facts")
        response.content["facts"]
      else
        fail! message: "Malformed response", response: response.content
      end
      if debug
        logger.info ">>> #{content}"
        logger.info "<<< #{facts.inspect}"
      end
      facts.each do |fact_data|
        build_fact(fact_data, message).save
      end
      message.update_column :facts_extracted, true
    rescue JSON::ParserError
      nil
    end

    def build_fact(data, message)
      Fact.new(
        character: Character.find_by(name: data["character"]),
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
