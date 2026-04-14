class SummarizeChatJob < ApplicationJob
  limits_concurrency to: 1,
                     key: ->(chat) { "summarize_chat_#{chat.id}" }

  def perform(chat)
    AI::Actors::SummarizeChat.call(chat:)
  end
end
