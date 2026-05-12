module SettingConcern
  Definition = Data.define(:name, :scope_path, :type, :default, :readonly, :static, :description) do
    def env_key
      prefix = scope_path.to_s.upcase.gsub(".", "__")
      "#{Setting::ENV_PREFIX}#{prefix}__#{name.to_s.upcase}"
    end

    def env_value
      ENV[env_key]
    end

    def overridden?
      ENV.key?(env_key)
    end

    def readonly?
      readonly || overridden?
    end

    def static?
      !!static
    end

    def default_value(context = nil)
      return default unless default.respond_to?(:call)
      return context.instance_exec(&default) if context

      default.call
    end

    def resolve(value)
      overridden? ? env_value : value
    end
  end
end
