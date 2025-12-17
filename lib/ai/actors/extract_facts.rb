module AI::Actors
  class ExtractFacts < Actor
    using Rainbow

    input :chat, type: Chat
    input :debug, type: [ TrueClass, FalseClass ], default: false

    def call
      puts assistant.instructions.faint if debug
      messages = chat.messages.visible.preload(facts: [ :character, :topic ]).order(:created_at)
      messages.each do |message|
        if message.facts_extracted
          assistant.add_message(role: :user, content: message.to_direct_speech)
          assistant.add_message(role: :assistant, content: message.facts.map(&:to_h).to_json)
        else
          extract_facts(message)
        end
      end
      dialog.update_column :facts_extracted, true
    end

    def extract_facts(message)
      content = message.to_direct_speech
      assistant.add_message(role: :user, content: content)
      response = assistant.complete
      json = response.content
      json.gsub! /\A(?:```json\n)?(.+?)(?:```\n?)?\z/m, '\1'
      if debug
        puts content.bright
        puts json.faint
      end
      data = JSON.parse(json)
      data.each do |fact_data|
        fact = build_fact(fact_data, message)
        fact.save
      end
      message.update_column :facts_extracted, true
    rescue JSON::ParserError
      nil
    end

    def build_fact(data, line)
      character = Character.find_by(name: data["character"])
      topic = resolve_topic(data)

      Fact.new character:,
               content: data["fact"],
               kind: data["kind"],
               persistent: data["persistent"],
               time: data["time"],
               date_from: data["date_from"],
               date_to: data["date_to"],
               importance: data["importance"],
               mentioned_at: line.created_at,
               dialog:,
               line:,
               topic:

    end

    private

    def resolve_topic(data)
      if data["topic_id"].present?
        Topic.find_by(id: data["topic_id"])
      elsif data["topic_name"].present?
        Topic.find_or_create_by(name: data["topic_name"])
      end
    end

    def assistant
      @assistant ||= begin
        AI.chat.with_prompt(:extract_facts, dialog:, topics: Topic.all).with_temperature(0.1)
      end
    end
  end
end
