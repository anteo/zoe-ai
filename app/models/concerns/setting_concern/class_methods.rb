module SettingConcern
  module ClassMethods
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

    def cached_data
      RequestStore.store[:settings_data] ||= load_data
    end

    def invalidate_cache!
      RequestStore.store.delete(:settings_data)
      RequestStore.store.delete(:setting_proxies)
    end

    def load_data
      return {} unless settings_table_available?

      all.each_with_object({}) do |row, h|
        (h[row.scope] ||= {})[row.key] = row.value
      end
    rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError, PG::ConnectionBad
      {}
    end

    def settings_table_available?
      return false unless connection.table_exists?(:settings)
      true
    rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError, PG::ConnectionBad
      false
    end

    # Calls block immediately and registers it for future changes to any of the given scopes.
    # For nested scopes, changes also fire hooks of all ancestor scopes.
    def watch(*scope_names, &block)
      block.call(nil)
      on_change(*scope_names, &block)
    end

    # Registers block for future changes only (no immediate call).
    def on_change(*scope_names, &block)
      scope_names.each { |s| CHANGE_HOOKS[s.to_sym] << block }
    end

    def run_change_hooks(scope_path, context: {})
      fired_hooks = context[:_setting_fired_hooks] ||= {}
      parts = scope_path.to_s.split(".")

      parts.length.downto(1) do |len|
        scope_name = parts.take(len).join(".").to_sym
        next if fired_hooks[scope_name]

        fired_hooks[scope_name] = true
        CHANGE_HOOKS[scope_name].each { |hook| hook.call(context) }
      end
    end

    # Re-runs setting hooks in the current process if DB-backed settings changed
    # since the last sync point in this process.
    def sync_hooks_if_stale!(context: {})
      return unless settings_table_available?

      HOOKS_SYNC_MUTEX.synchronize do
        latest_update = maximum(:updated_at)
        current_keys = pluck(:scope, :key).map { |scope, key| "#{scope}\0#{key}" }

        last_synced_at = @_hooks_synced_at
        last_keys = @_hooks_synced_keys || []

        if last_synced_at && current_keys == last_keys && !latest_update.nil? && latest_update <= last_synced_at
          return
        end

        if last_synced_at.nil? && @_hooks_synced_keys.nil?
          # First sync in this process: establish baseline without replaying all hooks.
          @_hooks_synced_at = latest_update
          @_hooks_synced_keys = current_keys
          return
        end

        deleted_scopes = (last_keys - current_keys).map { |entry| entry.split("\0", 2).first }
        added_scopes = (current_keys - last_keys).map { |entry| entry.split("\0", 2).first }

        changed_scopes = if last_synced_at.nil?
          (deleted_scopes + added_scopes).uniq
        else
          updated_scopes = where("updated_at > ?", last_synced_at).distinct.pluck(:scope)
          (updated_scopes + deleted_scopes + added_scopes).uniq
        end

        invalidate_cache!
        hook_context = context.merge(_setting_fired_hooks: {})
        changed_scopes.each { |scope_path| run_change_hooks(scope_path, context: hook_context) }

        @_hooks_synced_at = latest_update
        @_hooks_synced_keys = current_keys
      end
    rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError, PG::ConnectionBad
      nil
    end

    def scope(scope_name, &block)
      builder = SettingConcern::ScopeBuilder.new(scope_name.to_s)
      builder.instance_eval(&block)
      proxy_class = _build_proxy_class(builder)

      SCOPE_DEFINITIONS[scope_name.to_sym] = proxy_class
      _nested_proxy_classes[scope_name.to_sym] = proxy_class
      _nested_names << scope_name.to_sym

      define_singleton_method(scope_name) do
        (RequestStore.store[:setting_proxies] ||= {})[scope_name] ||= proxy_class.from_data(cached_data)
      end
    end

    private

    def _build_proxy_class(builder)
      proxy_class = Class.new(SettingConcern::ScopeProxy) do
        self.scope_path = builder.scope_path

        builder.defs.each do |attr_name, defn|
          am_opts = defn.default.nil? ? {} : { default: defn.default }
          attribute attr_name, defn.type, **am_opts
        end

        builder.defs.each_key do |attr_name|
          define_method(:"#{attr_name}_readonly?") { self.class._defs[attr_name].readonly? }
          define_method(:"#{attr_name}_static?") { self.class._defs[attr_name].static? }
          define_method(:"#{attr_name}_default") { self.class._defs[attr_name].default_value(self) }
        end

        _defs.merge!(builder.defs)

        builder.validations.each { |m, args, opts, blk| send(m, *args, **opts, &blk) }
      end

      builder.nested.each do |nested_name, nested_builder|
        child_proxy_class = _build_proxy_class(nested_builder)

        proxy_class.define_method(nested_name) do
          instance_variable_get(:"@#{nested_name}") ||
            instance_variable_set(:"@#{nested_name}", child_proxy_class.from_data(Setting.cached_data))
        end

        # Rails' fields_for detects this method and uses {name}_attributes as the param key.
        proxy_class.define_method(:"#{nested_name}_attributes=") do |attrs|
          send(nested_name).assign_attributes(attrs)
        end

        proxy_class._nested_names << nested_name
        proxy_class._nested_proxy_classes[nested_name] = child_proxy_class

        # Propagate child validity into parent errors.
        proxy_class.validate do
          child = send(nested_name)
          unless child.valid?
            child.errors.each { |e| errors.add("#{nested_name}.#{e.attribute}", e.message) }
          end
        end
      end

      proxy_class
    end
  end
end
