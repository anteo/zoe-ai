namespace :models do
  desc "Refresh models registry from configured providers and sync DB"
  task update: :environment do
    result = AI::Actors::RefreshModelsRegistry.result

    unless result.success?
      puts "ERROR: #{result.error}"
      exit(1)
    end

    stats = result.stats

    puts "Models refresh complete"
    puts "  Existing JSON models: #{stats[:existing_models_count]}"
    puts "  Refreshed models: #{stats[:refreshed_models_count]}"
    puts "  models.json updated: #{stats[:models_json_updated]}"
    puts "  DB models before: #{stats[:db_count_before]}"
    puts "  DB models after: #{stats[:db_count_after]}"
  end
end
