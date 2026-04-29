module SettingConcern
  module ScopeProxyBehavior
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
end
