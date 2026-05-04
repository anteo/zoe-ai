module Settings
  class AIProvidersComponent < ApplicationComponent
    def initialize(f:)
      @f = f
    end

    private

    attr_reader :f
  end
end
