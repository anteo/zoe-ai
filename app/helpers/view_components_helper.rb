module ViewComponentsHelper
  def component(name, **args, &block)
    render component_class(name).new(**args), layout: false, &block
  end

  def component_collection(name, collection)
    render component_class(name).with_collection(collection), layout: false
  end

  def component_class(name)
    component_name = name.to_s.gsub("__", "/")
    component_class = "#{component_name}_component".classify.safe_constantize

    raise "Component #{component_name}_component not found!" unless component_class
    component_class
  end
end
