module AI::Actors
  class DescribeCharacter < Actor
    input :character, type: Character
    input :logger, default: -> { Rails.logger }

    fail_on RubyLLM::Error

    def call
      logger.debug ">>> #{chat.instructions}"
      groups = character.grouped_persistent_facts
      summaries = summarize_groups(groups)
      description = format_description(summaries)
      logger.debug "<<< #{description}"
      character.update(description:, description_up_to_date: true)
    end

    private

    def summarize_groups(groups)
      groups.map do |period, topic_groups|
        summary = summarize_with_assistant(topic_groups)
        [ period, summary ]
      end
    end

    def chat
      @chat ||= AI::DescribeCharacterAgent.chat(character:)
    end

    def summarize_with_assistant(topic_groups)
      content = topic_groups.map do |topic_name, facts|
        lines = facts.map { "- #{it.to_description}" }.join("\n")
        "## #{topic_name}\n#{lines}"
      end.join("\n\n")

      logger.debug ">>> #{content}"
      chat.add_message(role: :user, content: content)
      response = chat.complete
      response.content.strip
    end

    def format_description(summaries)
      summaries.map do |period, summary|
        from_attr = period.begin ? %( from="#{period.begin.strftime("%B %Y")}") : ""
        to_attr = period.end ? %( to="#{period.end.strftime("%B %Y")}") : ""

        "<period#{from_attr}#{to_attr}>\n#{summary}\n</period>"
      end.join("\n\n")
    end
  end
end
