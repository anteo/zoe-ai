module SettingConcern
  class ScopeProxy
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveRecord::AttributeMethods::Query
    extend SettingConcern::ScopeProxyBehavior

    class_attribute :scope_path # dotted for nested, e.g. "mailer.smtp"

    def self.inherited(subclass)
      super
      subclass.instance_variable_set(:@_defs, {})
      subclass.instance_variable_set(:@_nested_names, [])
      subclass.instance_variable_set(:@_nested_proxy_classes, {})
    end

    def self.model_name
      ActiveModel::Name.new(self, nil, scope_path.to_s.split(".").last)
    end

    def self.human_attribute_name(attribute, options = {})
      options ||= {}
      path = scope_path.presence
      return super(attribute, options) unless path

      I18n.t(
        "settings.#{path}.#{attribute}",
        **options,
        default: super(attribute, options)
      )
    end

    def self.from_data(data)
      db_attrs = data[scope_path.to_s] || {}
      attrs = _defs.filter_map do |attr_name, definition|
        next unless db_attrs.key?(attr_name.to_s) || definition.overridden?
        [ attr_name, definition.resolve(db_attrs[attr_name.to_s]) ]
      end.to_h
      new(attrs)
    end

    def persisted? = true

    def to_param = nil # always specify url: explicitly in form_with

    def id = nil

    def save(context: {})
      return false unless valid?

      self.class._defs.each do |attr_name, definition|
        next if definition.readonly?

        value = send(attr_name)
        # Treat blank strings as nil so clearing a field removes the DB row.
        normalized = value.is_a?(String) ? value.presence : value
        record = Setting.find_or_initialize_by(scope: self.class.scope_path.to_s, key: attr_name.to_s)
        if normalized.nil?
          record.destroy if record.persisted?
        else
          record.value = normalized.to_s
          record.save!
        end
      end

      return false unless self.class._nested_names.all? do |name|
        instance_variable_get(:"@#{name}")&.save(context:) != false
      end

      Setting.invalidate_cache!
      Setting.run_change_hooks(self.class.scope_path, context:)
      true
    end

    def update(context: {}, **attrs)
      assign_attributes(attrs)
      save(context:)
    end
  end
end
