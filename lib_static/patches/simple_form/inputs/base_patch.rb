module Patches
  module SimpleForm
    module Inputs
      module BasePatch
        private

        def merge_wrapper_options(options, wrapper_options)
          html_options = super
          return html_options unless self.options[:validator] == false

          html_options[:class] = Array(html_options[:class]).flat_map { |value| value.to_s.split }.excluding("validator").presence
          html_options
        end
      end
    end
  end
end
