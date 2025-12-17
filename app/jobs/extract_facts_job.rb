class ExtractFactsJob < ApplicationJob
  limits_concurrency to: 1,
                     key: ->(chat) { "extract_facts_chat_#{chat.id}" },
                     duration: 5.minutes,
                     on_conflict: :discard

  def perform(chat)
    AI::Actors::ExtractFacts.call(dialog: chat)
  end
end
