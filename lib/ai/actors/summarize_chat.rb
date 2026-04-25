module AI::Actors
  class SummarizeChat < Actor
    input :chat, type: Chat
    input :logger, default: -> { Rails.logger }

    fail_on RubyLLM::Error

    def call
      messages = chat.messages.visible.order(:created_at)
      if messages.empty?
        chat.update! summary: "**Chat is empty**"
        return
      end

      text = messages.map { it.to_timestamp_message }.join("\n")
      logger.debug ">>> Summarizing chat ##{chat.id} (#{messages.size} messages)"

      llm_chat = AI::Agents::SummarizeChat.chat(chat:)
      response = llm_chat.ask(text)

      logger.debug "<<< Summary: #{response.content.truncate(200)}"
      chat.update!(summary: response.content)
    end
  end
end
