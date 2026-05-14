module Patches
  module Turbo
    module StreamsChannelPatch
      extend ActiveSupport::Concern

      class_methods do
        def broadcast_component_replace_to(*streamables, target:, component:, **args, &block)
          broadcast_replace_to(*streamables,
                               target:,
                               html: ApplicationController.component(component, **args, &block))
        end
      end
    end
  end
end
