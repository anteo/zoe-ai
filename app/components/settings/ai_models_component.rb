module Settings
  class AIModelsComponent < ApplicationComponent
    def initialize(f:)
      @f = f
    end

    private

    attr_reader :f
  end
end
