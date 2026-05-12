module Settings
  class SectionComponent < ApplicationComponent
    renders_one :footer

    def initialize(f:)
      @f = f
    end

    private

    attr_reader :f
  end
end
