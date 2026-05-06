class RefreshModelsRegistryJob < ApplicationJob
  limits_concurrency to: 1,
                     key: ->(*) { "refresh_models_registry" },
                     on_conflict: :discard

  def perform
    logger.info "RefreshModelsRegistryJob started..."

    stats = AI::Actors::RefreshModelsRegistry.call(logger:).stats

    logger.info "* Existing JSON models: #{stats[:existing_models_count]}"
    logger.info "* Refreshed models: #{stats[:refreshed_models_count]}"
    logger.info "* models.json updated: #{stats[:models_json_updated]}"
    logger.info "* DB models before: #{stats[:db_count_before]}"
    logger.info "* DB models after: #{stats[:db_count_after]}"
    logger.info "Models refresh complete!"
  rescue => e
    logger.error "RefreshModelsRegistryJob failed: #{e.message}"
    logger.debug e.backtrace
    raise
  end
end
