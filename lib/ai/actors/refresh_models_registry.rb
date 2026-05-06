require "json-schema"

module AI::Actors
  class RefreshModelsRegistry < Actor
    input :logger, default: -> { Rails.logger }
    output :stats

    fail_on RubyLLM::Error,
            ActiveRecord::ActiveRecordError,
            JSON::Schema::ValidationError

    def call
      existing_models = RubyLLM::Models.read_from_json
      refreshed_models = RubyLLM.models.refresh!

      if refreshed_models.all.empty? && existing_models.empty?
        fail! error: "Failed to fetch models"
      end

      changed = registry_changed?(existing_models, refreshed_models.all)
      save_registry!(refreshed_models) if changed

      before_count = Model.count
      Model.save_to_database
      after_count = Model.count

      self.stats = build_stats(
        existing_models_count: existing_models.size,
        refreshed_models: refreshed_models.all,
        models_json_updated: changed,
        db_count_before: before_count,
        db_count_after: after_count
      )
    end

    private

    def registry_changed?(existing_models, refreshed_models)
      sorted_models_data(existing_models) != sorted_models_data(refreshed_models)
    end

    def save_registry!(models)
      validate_models!(models)
      models.save_to_json
    end

    def validate_models!(models)
      schema_path = Rails.root.join("config/models_schema.json").to_s
      models_data = models.all.map(&:to_h)
      validation_errors = JSON::Validator.fully_validate(schema_path, models_data)

      return if validation_errors.empty?

      fail! error: validation_errors.first
    end

    def sorted_models_data(models)
      models.map(&:to_h)
            .sort_by { |model| [ model[:provider].to_s, model[:id].to_s ] }
    end

    def build_stats(existing_models_count:, refreshed_models:, models_json_updated:, db_count_before:, db_count_after:)
      {
        existing_models_count: existing_models_count,
        refreshed_models_count: refreshed_models.size,
        models_json_updated: models_json_updated,
        db_count_before: db_count_before,
        db_count_after: db_count_after,
        provider_counts: refreshed_models.group_by(&:provider).transform_values(&:count)
      }
    end
  end
end
