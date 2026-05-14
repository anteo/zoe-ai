module Datatable
  class BaseComponent < ApplicationComponent
    class_attribute :configured_default_sort, instance_accessor: false
    class_attribute :configured_empty_state_i18n_key, instance_accessor: false
    class_attribute :configured_frame_id, instance_accessor: false
    class_attribute :configured_page_param, default: :page, instance_accessor: false
    class_attribute :configured_path_helper, instance_accessor: false
    class_attribute :configured_per_page, instance_accessor: false
    class_attribute :configured_row_component_class, instance_accessor: false
    class_attribute :configured_footer_component_class, instance_accessor: false
    class_attribute :configured_filters_component_class, instance_accessor: false
    class_attribute :configured_filters_model_class, instance_accessor: false
    class_attribute :configured_header_component_class, instance_accessor: false
    class_attribute :configured_model_class, instance_accessor: false
    attr_reader :filters, :pagy, :params, :path, :records, :search

    class << self
      def component_basename
        configured_model_class ? configured_model_class.name.pluralize.demodulize : name.demodulize.delete_suffix("DatatableComponent")
      end

      def component_name
        name.underscore.delete_suffix("_component").tr("/", "__").to_sym
      end

      def component_namespace
        namespace = name.deconstantize
        namespace.presence
      end

      def default_sort(value = nil)
        return configured_default_sort if value.nil?

        self.configured_default_sort = value
      end

      def empty_state_i18n_key(value = nil)
        return configured_empty_state_i18n_key || :text_nothing_found if value.nil?

        self.configured_empty_state_i18n_key = value
      end

      def footer_component_class(value = nil)
        return configured_footer_component_class || infer_component_class("Footer") if value.nil?

        self.configured_footer_component_class = value
      end

      def frame_id(value = nil)
        return configured_frame_id || name.underscore.delete_suffix("_component").tr("/", "__") if value.nil?

        self.configured_frame_id = value
      end

      def filters_component_class(value = nil)
        return configured_filters_component_class || infer_optional_component_class("Filters") if value.nil?

        self.configured_filters_component_class = value
      end

      def filters_model_basename
        configured_model_class ? configured_model_class.name.demodulize : name.demodulize.delete_suffix("DatatableComponent").singularize
      end

      def filters_model_class(value = nil)
        return configured_filters_model_class || infer_optional_nested_filters_model_class || infer_optional_filters_model_class || Datatable::FiltersForm if value.nil?

        self.configured_filters_model_class = value
      end

      def header_component_class(value = nil)
        return configured_header_component_class || infer_component_class("Header") if value.nil?

        self.configured_header_component_class = value
      end

      def model(value = nil)
        return configured_model_class if value.nil?

        self.configured_model_class = value
      end

      def page_param(value = nil)
        return configured_page_param if value.nil?

        self.configured_page_param = value
      end

      def path_helper(value = nil)
        return configured_path_helper if value.nil?

        self.configured_path_helper = value
      end

      def per_page(value = nil)
        return configured_per_page || Setting.ui.datatable_per_page if value.nil?

        self.configured_per_page = value
      end

      def row_component_class(value = nil)
        return configured_row_component_class || infer_component_class("Row") if value.nil?

        self.configured_row_component_class = value
      end

      def row_component_name
        row_component_class.name.underscore.delete_suffix("_component").tr("/", "__").to_sym
      end

      def row_dom_id(record)
        ActionView::RecordIdentifier.dom_id(record)
      end

      def results_frame_id
        "#{frame_id}__results"
      end

      def stream_name
        frame_id.to_s
      end

      private

      def infer_component_class(suffix)
        class_name = [ component_namespace, "#{component_basename}#{suffix}Component" ].compact.join("::")
        class_name.constantize
      end

      def infer_optional_component_class(suffix)
        class_name = [ component_namespace, "#{component_basename}#{suffix}Component" ].compact.join("::")
        class_name.safe_constantize
      end

      def infer_optional_filters_model_class
        class_name = [ component_namespace, "#{filters_model_basename}Filters" ].compact.join("::")
        class_name.safe_constantize
      end

      def infer_optional_nested_filters_model_class
        filters_component_class&.const_get(:Model, false)
      rescue NameError
        nil
      end
    end

    def initialize(records:, pagy:, search:, params:, path: nil, filters: nil)
      @filters = filters || self.class.filters_model_class.new
      @records = records
      @pagy = pagy
      @params = params
      @path = path
      @search = search
    end

    def body_id
      "#{frame_id}__body"
    end

    def container_classes
      "space-y-4"
    end

    def empty_state_i18n_key
      self.class.empty_state_i18n_key
    end

    def empty_state_classes
      "w-full rounded-box border border-base-300 bg-base-100 p-3 text-center"
    end

    def footer_component
      self.class.footer_component_class.new(pagy:, records:, datatable: self)
    end

    def filters_component
      filters_component_class = self.class.filters_component_class
      return unless filters_component_class

      filters_component_class.new(datatable: self, filters:)
    end

    def filters_component?
      filters_component.present?
    end

    def frame_id
      self.class.frame_id
    end

    def header_component
      self.class.header_component_class.new(search:, datatable: self)
    end

    def page_param
      self.class.page_param
    end

    def request_path
      path || helpers.public_send(self.class.path_helper)
    end

    def results_component
      Datatable::ResultsComponent.new(datatable: self)
    end

    def results_frame_id
      self.class.results_frame_id
    end

    def row_component(record)
      self.class.row_component_class.new(datatable: self, record:)
    end

    def row_dom_id(record)
      self.class.row_dom_id(record)
    end

    def row_present?(record)
      records.any? { |row| row.id == record.id }
    end

    def table_classes
      "table table-zebra table-sm w-full"
    end

    def table_wrapper_classes
      "overflow-x-auto rounded-box border border-base-300 bg-base-100"
    end

    def empty?
      records.empty?
    end

    def url_for_params(next_params)
      query_params = next_params.deep_dup
      query_params.compact_blank! if query_params.respond_to?(:compact_blank!)
      query_string = Rack::Utils.build_nested_query(query_params)

      query_string.present? ? "#{request_path}?#{query_string}" : request_path
    end
  end
end
