module SettingConcern
  class ScopeBuilder
    attr_reader :scope_path, :defs, :nested, :validations

    def initialize(scope_path)
      @scope_path = scope_path
      @defs = {}
      @nested = {}
      @validations = []
    end

    def setting(name, type = :string, default: nil, readonly: false, static: false, description: nil)
      name = name.to_sym
      @defs[name] = SettingConcern::Definition.new(
        name:,
        scope_path:,
        type:,
        default:,
        readonly:,
        static:,
        description:
      )
    end

    def scope(name, &block)
      child = SettingConcern::ScopeBuilder.new("#{@scope_path}.#{name}")
      child.instance_eval(&block)
      @nested[name.to_sym] = child
    end

    # Capture validation declarations and replay them on the proxy class.
    def validates(*args, **opts, &block)
      @validations << [ :validates, args, opts, block ]
    end

    def validate(*args, &block)
      @validations << [ :validate, args, {}, block ]
    end
  end
end
