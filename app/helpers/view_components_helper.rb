module ViewComponentsHelper
  def component(name, **args, &block)
    component_class = "#{name}_component".classify.safe_constantize

    raise "Component #{name}_component not found!" unless component_class

    render component_class.new(**args), &block
  end
end
