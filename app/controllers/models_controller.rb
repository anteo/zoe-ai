class ModelsController < ApplicationController
  before_action :require_admin!

  def search
    @models = Model
      # .where("metadata ->> 'source' IS NULL")
      .yield_self { |scope| apply_kind_filter(scope) }
      .yield_self { |scope| apply_query(scope) }
      .order(:model_id)

    render "models/search", layout: false
  end

  private

  def apply_query(scope)
    query = params[:q].to_s.strip
    return scope if query.blank?

    escaped = ActiveRecord::Base.sanitize_sql_like(query)
    scope.where("model_id ILIKE :q OR name ILIKE :q OR provider ILIKE :q", q: "%#{escaped}%")
  end

  def apply_kind_filter(scope)
    case params[:kind].to_s
    when "embedding"
      with_output(scope, "embeddings")
    when "image"
      with_output(scope, "image")
    else
      with_output(scope, "text")
    end
  end

  def with_output(scope, output_kind)
    scope.where("modalities -> 'output' ? :output_kind", output_kind:)
  end
end
