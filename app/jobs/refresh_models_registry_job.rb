class RefreshModelsRegistryJob < ApplicationJob
  limits_concurrency to: 1,
                     key: ->(*) { "refresh_models_registry" },
                     on_conflict: :discard

  def perform
    AI.console.info "RefreshModelsRegistryJob started..."

    stats = AI::Actors::RefreshModelsRegistry.call.stats

    AI.console.info "* Existing JSON models: #{stats[:existing_models_count]}"
    AI.console.info "* Refreshed models: #{stats[:refreshed_models_count]}"
    AI.console.info "* models.json updated: #{stats[:models_json_updated]}"
    AI.console.info "* DB models before: #{stats[:db_count_before]}"
    AI.console.info "* DB models after: #{stats[:db_count_after]}"
    AI.console.info "Models refresh complete!"
  rescue => e
    AI.console.error "RefreshModelsRegistryJob failed: #{e.message}"
    raise
  end
end
