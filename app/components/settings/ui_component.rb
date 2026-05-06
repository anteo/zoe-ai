module Settings
  class UIComponent < ApplicationComponent
    def initialize(f:)
      @f = f
    end

    private

    attr_reader :f
  end
end
