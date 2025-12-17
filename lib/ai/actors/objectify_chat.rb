module AI::Actors
  class ObjectifyChat < Actor
    using Rainbow

    input :dialog, type: Dialog

    def call
      instructions = <<~TEXT
        You will be presented with a dialogue between two people (#{dialog.initiator.name} and #{dialog.companion.name})
        Answer each replica with a paraphrased replica so that its meaning is clear outside the dialogue,
        that is, pronouns such as “you”, “he”, “it” and others, if necessary, were replaced by names
        and the names of objects or people from this dialogue. Don't use direct speech.
      TEXT
      assistant = AI.chat.with_instructions(instructions).with_temperature(0.1)
      dialog.lines.order(created_at: :asc).each { |line| objectify_line(assistant:, line:) }
      dialog.update(objectified: true)
    end

    def objectify_line(assistant:, line:)
      content = line.to_direct_speech
      assistant.add_message(role: :user, content: content)
      response = assistant.complete
      objectified_text = response.content
      embedding = AI.embed("categorize_topic: #{objectified_text}").vectors.first
      line.update(objectified_text:,
                  embedding:)
      puts line.text.faint
      puts objectified_text.faint.green
    end
  end
end
