# Encapsulates class and parameters for a data source, mapper, and reducer
class WorkflowComponent
  def initialize(component_class, params = {})
    @component_class = component_class
    @params = params
  end

  # make a new instance of the given component class & params
  def new
    component_class.new(**params)
  end

  def to_s
    component_class.to_s
  end

  def to_h
    {
      component_class: component_class,
      params: params
    }
  end

  attr_reader :component_class, :params
end
