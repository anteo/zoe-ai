module Datatable
  class FiltersForm
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Attributes::Normalization
    include ActiveModel::Translation

    class_attribute :configured_preserved_attribute_names, default: %w[s], instance_accessor: false

    class << self
      def from_params(params)
        new((params || {}).to_h)
      end

      def model_name
        @model_name ||= ActiveModel::Name.new(self, nil, inferred_model_name)
      end

      def preserve_attributes(*names)
        self.configured_preserved_attribute_names = names.flatten.map(&:to_s)
      end

      def preserved_attribute_names
        configured_preserved_attribute_names
      end

      private

      def inferred_model_name
        inferred_name = name.demodulize == "Model" ? name.deconstantize.demodulize : name.demodulize
        inferred_name.delete_suffix("Component")
      end
    end

    attribute :s, :string

    normalizes :s, with: ->(value) { value.to_s.strip.presence }

    def preserved_attributes
      attributes.slice(*self.class.preserved_attribute_names).compact_blank
    end

    def common_ransack_params
      {}.tap do |params|
        params["s"] = normalized_sorts if normalized_sorts.present?
      end
    end

    def specific_ransack_params
      attributes.compact_blank
    end

    def to_ransack_params
      specific_ransack_params.merge(common_ransack_params)
    end

    def normalized_sorts
      s.to_s.split(",").map(&:strip).reject(&:blank?)
    end
  end
end
