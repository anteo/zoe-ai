module Settings
  class SectionComponent < ApplicationComponent
    class << self
      attr_reader :configured_form_enabled, :configured_form_html, :configured_form_scope, :configured_icon_class, :configured_parent_section

      def form_enabled(value = nil)
        return @configured_form_enabled if value.nil?

        @configured_form_enabled = value
      end

      def form_html(value = nil, &block)
        return @configured_form_html if value.nil? && !block_given?

        @configured_form_html = block_given? ? block : value
      end

      def form_scope(value = nil)
        return @configured_form_scope if value.nil?

        @configured_form_scope = value
      end

      def icon_class(value = nil)
        return @configured_icon_class if value.nil?

        @configured_icon_class = value
      end

      def parent_section(value = nil)
        return @configured_parent_section if value.nil?

        @configured_parent_section = value&.to_s
      end
    end

    attr_accessor :f

    def initialize(f: nil)
      @f = f
    end

    def form?
      self.class.configured_form_enabled == true
    end

    def form_html_options
      self.class.configured_form_html&.call || {}
    end

    def form_object
      form_scope.split(".").reduce(Setting, :public_send)
    end

    def form_scope
      self.class.form_scope || section_key.tr("_", ".")
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

    def parent_section
      self.class.parent_section
    end

    def section_icon_class
      self.class.icon_class
    end

    def section_key
      self.class.name.demodulize.delete_suffix("Component").underscore
    end

    def section_label
      I18n.t(:"label_settings_#{section_key}")
    end
  end
end
