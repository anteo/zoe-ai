namespace :ai do
  # desc "Objectify chats"
  # task objectify_chats: :environment do
  #   Chat.where(objectified: false).find_each do |chat|
  #     AI::Actors::ObjectifyChat.call(chat:)
  #   end
  # end

  desc "Collect facts"
  task extract_facts: :environment do
    Dialog.where(facts_extracted: false).find_each do |chat|
      AI::Actors::ExtractFacts.call(dialog:)
    end
  end

  # desc "Summarize chats"
  # task summarize_chats: :environment do
  #   Chat.where(summary: nil).find_each do |chat|
  #     AI::Actors::SummarizeChat.call(chat:)
  #   end
  # end

  desc "Describe characters"
  task describe_characters: :environment do
    characters = Character.all
    characters = characters.where(description_up_to_date: false) unless ENV["FORCE"]
    characters.find_each do |character|
      AI::Actors::DescribeCharacter.call(character:)
    end
  end

  # desc "Process chats"
  # task process_chats: [ :objectify_chats, :summarize_chats, :extract_facts ]
  # task process_chats: [ :extract_facts ]

  # desc "Run processing"
  # task run_processing: [ :process_chats, :describe_persons ]

  # desc "Regenerate embeddings"
  # task regenerate_embeddings: :environment do
  #   Line.find_each do |line|
  #     line.update_column :embedding, AI.embedding_llm.embed(text: line.objectified_text || line.text).embedding
  #   end
  # end
end
