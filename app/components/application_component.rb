class ApplicationComponent < ViewComponent::Base
  include Turbo::StreamsHelper
  include ViewComponentsHelper
  include ApplicationHelper

  def to_s
    ApplicationController.render(self, layout: false)
  end

  def name
    self.class.name.underscore.gsub("/", "__").to_sym
  end
end
