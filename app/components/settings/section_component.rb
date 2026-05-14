module Settings
  class SectionComponent < ApplicationComponent
    attr_accessor :f

    def initialize(f: nil)
      @f = f
    end

    def footer?
      helpers.content_for?(:"#{name}_footer")
    end

    def footer(&block)
      helpers.content_for(:"#{name}_footer", &block)
    end

    def header?
      helpers.content_for?(:"#{name}_header")
    end

    def header(&block)
      helpers.content_for(:"#{name}_header", &block)
    end
  end
end
