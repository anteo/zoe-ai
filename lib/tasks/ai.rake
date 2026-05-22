namespace :ai do
  def logger
    @logger ||= ActiveSupport::TaggedLogging.new(Logger.new($stdout))
  end

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
      describe_res = AI::Actors::DescribeMessageAttachments.result(chat:, logger:)
      unless describe_res.success?
        puts "  Error: #{describe_res.error}"
        next
      end

      res = AI::Actors::ExtractFacts.result(chat:, logger:)
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
    partner = if ENV["PARTNER_ID"].present?
      Character.find(ENV["PARTNER_ID"])
    else
      Character.default_ai
    end

    characters = Character.all
    characters = characters.where(id: ENV["CHARACTER_ID"]) if ENV["CHARACTER_ID"].present?
    characters.find_each do |character|
      res = AI::Actors::DescribeCharacter.result(character:, partner:)
      unless res.success?
        puts "  Error: #{res.error}"
        next
      end

      puts "## #{character.name}"
      puts res.description
      puts
    end
  end

  desc "Aggregate persistent facts"
  task aggregate_persistent_facts: :environment do
    if ENV["CHARACTER_ID"].present?
      character = Character.find(ENV["CHARACTER_ID"])
      partner = if ENV["PARTNER_ID"].present?
        Character.find(ENV["PARTNER_ID"])
      else
        Character.default_ai
      end
      AI::Actors::AggregatePersistentFacts.call(character:, partner:, logger:)
    else
      AI::Actors::RunAggregatePersistentFacts.call(logger:)
    end
  end

  desc "Summarize fact aggregates (pending and failed by default, or explicit IDs via FACT_AGGREGATE_IDS=1,2,3)"
  task summarize_fact_aggregates: :environment do
    ids = ENV.fetch("FACT_AGGREGATE_IDS", "")
             .split(/[,\s]+/)
             .map(&:strip)
             .select { |it| it.match?(/\A\d+\z/) }
             .map(&:to_i)
             .uniq

    aggregates = if ids.any?
      FactAggregate.where(id: ids).order(:id)
    else
      FactAggregate.where(summary_status: %w[pending failed]).order(:id)
    end

    puts "Processing summaries for #{aggregates.count} fact aggregate(s)..."
    puts "IDs filter: #{ids.join(', ')}" if ids.any?

    found_ids = aggregates.pluck(:id)
    missing_ids = ids - found_ids
    puts "Missing IDs: #{missing_ids.join(', ')}" if missing_ids.any?

    aggregates.find_each do |fact_aggregate|
      puts "  FactAggregate ##{fact_aggregate.id} (kind=#{fact_aggregate.kind}, status=#{fact_aggregate.summary_status})"
      res = AI::Actors::SummarizeFactAggregate.result(fact_aggregate:, logger:)
      puts "  Error: #{res.error}" unless res.success?
    end

    puts "Done."
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
