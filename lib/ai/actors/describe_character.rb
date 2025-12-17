module AI::Actors
  class DescribeCharacter < Actor
    using Rainbow

    input :character, type: Character

    def call
      groups = character.grouped_persistent_facts
      summaries = summarize_groups(groups)
      description = format_description(summaries)
      puts description.faint.green
      character.update(description:, description_up_to_date: true)
    end

    private

    def summarize_groups(groups)
      groups.map do |period, facts|
        summary = summarize_with_assistant(facts)

        [ period, summary ]
      end
    end

    def chat
      @dialog ||= begin
        AI.chat.with_prompt(:describe_character, character:).with_temperature(0.1)
      end
    end

    def summarize_with_assistant(facts)
      content = facts.map { "- #{it}" }.join("\n")
      chat.add_message(role: :user, content: content)
      response = chat.complete
      response.content.strip
    end

    def format_description(summaries)
      summaries.map do |period, summary|
        start_time = period.begin
        end_time = period.end

        header = if start_time && end_time
          "From #{start_time.strftime("%B %Y")} to #{end_time.strftime("%B %Y")}"
        elsif start_time.nil? && end_time
          "Before #{end_time.strftime("%B %Y")}"
        elsif start_time && end_time.nil?
          "From #{start_time.strftime("%B %Y")} onward"
        end

        "#{header}:\n\n#{summary}"
      end.join("\n\n")
    end
  end
end
