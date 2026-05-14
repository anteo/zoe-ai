module SettingConcern
  class ScopeProxy
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveRecord::AttributeMethods::Query

    class_attribute :scope_path # dotted for nested, e.g. "mailer.smtp"

    class << self
      def inherited(subclass)
        super

        subclass.instance_variable_set(:@_defs, {})
        subclass.instance_variable_set(:@_nested_names, [])
        subclass.instance_variable_set(:@_nested_proxy_classes, {})
      end

      def model_name
        ActiveModel::Name.new(self, nil, scope_path.to_s.split(".").last)
      end

      def human_attribute_name(attribute, options = {})
        options ||= {}
        path = scope_path.presence
        return super(attribute, options) unless path

        I18n.t(
          "settings.#{path}.#{attribute}",
          **options,
          default: super(attribute, options)
        )
      end

      def from_data(data)
        db_attrs = data[scope_path.to_s] || {}
        attrs = _defs.filter_map do |attr_name, definition|
          next unless db_attrs.key?(attr_name.to_s) || definition.overridden?
          [ attr_name, definition.resolve(db_attrs[attr_name.to_s]) ]
        end.to_h
        new(attrs)
      end

      def _defs
        @_defs ||= {}
      end

      def _nested_names
        @_nested_names ||= []
      end

      def _nested_proxy_classes
        @_nested_proxy_classes ||= {}
      end

      def permitted_attributes
        writable = _defs.reject { |_, d| d.readonly? }.keys
        nested = _nested_proxy_classes.transform_keys { |k| :"#{k}_attributes" }
                                      .transform_values(&:permitted_attributes)
        writable + (nested.empty? ? [] : [ nested ])
      end
    end

    def persisted? = true

    def to_param = nil # always specify url: explicitly in form_with

    def id = nil

    def initialize(attributes = nil)
      provided_attributes = attributes&.to_h&.stringify_keys || {}
      super(attributes)
      apply_callable_defaults(provided_attributes)
    end

    def save(context: {})
      success, changed_scopes = save_with_changes(context:)
      return false unless success

      Setting.invalidate_cache!
      return true if changed_scopes.empty?

      hook_context = context.merge(_setting_fired_hooks: {})
      changed_scopes.each { |scope_path| Setting.run_change_hooks(scope_path, context: hook_context) }
      true
    end

    def update(context: {}, **attrs)
      assign_attributes(attrs)
      save(context:)
    end

    private

    def apply_callable_defaults(provided_attributes)
      self.class._defs.each do |attr_name, definition|
        next unless definition.default.respond_to?(:call)
        next if provided_attributes.key?(attr_name.to_s)
        next if public_send(attr_name).present?

        public_send(:"#{attr_name}=", definition.default_value(self))
      end
    end

    def save_with_changes(context:)
      return [ false, [] ] unless valid?

      changed_scopes = []
      changed = false
      scope_path = self.class.scope_path.to_s
      scope_data = Setting.cached_data[scope_path] || {}

      self.class._defs.each do |attr_name, definition|
        next if definition.readonly?

        value = send(attr_name)
        # Treat blank strings as nil so clearing a field removes the DB row.
        normalized = value.is_a?(String) ? value.presence : value
        key = attr_name.to_s
        persisted = scope_data[key]
        has_persisted = scope_data.key?(key)

        next unless attr_changed_for_persistence?(attr_name, definition, normalized, persisted, has_persisted)

        record = Setting.find_or_initialize_by(scope: scope_path, key:)
        if normalized.nil?
          record.destroy if record.persisted?
        else
          record.value = normalized.to_s
          record.save!
        end
        changed = true
      end

      self.class._nested_names.each do |name|
        child = instance_variable_get(:"@#{name}")
        next unless child

        child_success, child_changed_scopes = child.send(:save_with_changes, context:)
        return [ false, [] ] unless child_success

        changed_scopes.concat(child_changed_scopes)
      end

      changed_scopes << scope_path if changed
      [ true, changed_scopes.uniq ]
    end

    def attr_changed_for_persistence?(attr_name, definition, normalized, persisted, has_persisted)
      return has_persisted if normalized.nil?
      unless has_persisted
        default_value = definition.default_value(self)
        return normalized != default_value
      end

      type = self.class.attribute_types[attr_name.to_s]
      persisted_cast = type ? type.cast(persisted) : persisted
      persisted_cast != normalized
    end
  end
end
