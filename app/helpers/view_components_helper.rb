module ViewComponentsHelper
  def component(name, **args, &block)
    component_name = name.to_s
    component_class = "#{component_name}_component".classify.safe_constantize

    raise "Component #{component_name}_component not found!" unless component_class

    render component_class.new(**args), &block
  end
end
