module DatatableSupport
  extend ActiveSupport::Concern

  included do
    attr_reader :datatable
  end

  private

  def render_datatable(datatable_class, **component_options)
    load_datatable(datatable_class:, scope: datatable_class.datatable_scope(self), **component_options)

    component = turbo_frame_request_id == @datatable.results_frame_id ? @datatable.results_component : @datatable
    render component, layout: false
  end

  def load_datatable(datatable_class:, scope:, **component_options)
    filters = datatable_class.filters_model_class.from_params(ransack_params)
    search = scope.ransack(filters.to_ransack_params)
    search.sorts = normalize_sorts(datatable_class.default_sort) if search.sorts.empty? && datatable_class.default_sort.present?
    filters.s = search.sorts.map { |sort| "#{sort.name} #{sort.dir}" }.join(", ").presence

    pagy, records = pagy(search.result, limit: datatable_class.per_page, page_param: datatable_class.page_param)

    @filters = filters
    @q = search
    @pagy = pagy
    @records = records
    @datatable = datatable_class.new(
      filters:,
      records:,
      pagy:,
      params: datatable_params(datatable_class),
      path: request.path,
      search:,
      **component_options
    )
  end

  def datatable_params(datatable_class)
    request.query_parameters.deep_dup.tap do |query_params|
      query_params[datatable_class.page_param.to_s] = params[datatable_class.page_param] if params[datatable_class.page_param].present?
    end
  end

  def ransack_params
    query = params[:q]
    return query if query.is_a?(Hash)
    return {} unless query.respond_to?(:to_unsafe_h)

    query.to_unsafe_h
  end

  def normalize_sorts(sorts)
    Array.wrap(sorts).flat_map { |value| value.to_s.split(",") }.map(&:strip).reject(&:blank?)
  end
end
