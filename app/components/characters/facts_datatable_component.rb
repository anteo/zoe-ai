module Characters
  class FactsDatatableComponent < Datatable::BaseComponent
    model Fact
    default_sort "mentioned_at desc, created_at desc"
    footer_component_class Datatable::FooterComponent
    pagination :both

    attr_reader :character, :editable

    def initialize(character:, editable:, **kwargs)
      @character = character
      @editable = editable
      super(**kwargs)
    end

    def topic_options
      @topic_options ||= character.facts.joins(:topic).distinct.order("topics.name asc").pluck("topics.name")
    end
  end
end
