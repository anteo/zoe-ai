namespace :ai do
  # desc "Objectify chats"
  # task objectify_chats: :environment do
  #   Chat.where(objectified: false).find_each do |chat|
  #     AI::Actors::ObjectifyChat.call(chat:)
  #   end
  # end

  desc "Collect facts"
  task extract_facts: :environment do
    chats = Chat.where(facts_extracted: false).order(created_at: :asc)
    puts "Extracting facts for #{chats.count} chats..."
    chats.find_each do |chat|
      puts "  Chat ##{chat.id}"
      res = AI::Actors::ExtractFacts.result(chat:, logger: Logger.new(STDOUT))
      unless res.success?
        puts "  Error: #{res.error}"
      end
    end
    puts "Done."
  end

  desc "Re-extract all facts from scratch (deletes existing facts, resets flags, re-runs extraction)"
  task reextract_facts: :environment do
    puts "Deleting all facts..."
    Fact.delete_all
    puts "Resetting extraction flags..."
    Message.update_all(facts_extracted: false)
    Chat.update_all(facts_extracted: false)

    puts "Re-extracting facts..."
    Rake::Task["ai:extract_facts"].invoke
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
      res = AI::Actors::DescribeCharacter.result(character:)
      unless res.success?
        puts "  Error: #{res.error}"
      end
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
