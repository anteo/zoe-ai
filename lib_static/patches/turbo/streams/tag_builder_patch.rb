module Patches
  module Turbo
    module Streams
      module TagBuilderPatch
        extend ActiveSupport::Concern

        def redirect(url)
          turbo_stream_action_tag :redirect, url:
        end

        def close_modal(id = @view_context.turbo_frame_request_id)
          turbo_stream_action_tag :close_modal, id:
        end

        def show_modal(html)
          append("modal-stack", html)
        end

        def update_component(target, component, method: :morph, **args, &block)
          update(target, @view_context.component(component, **args, &block), method:)
        end

        def replace_component(target, component, method: :morph, **args, &block)
          replace(target, @view_context.component(component, **args, &block), method:)
        end
      end
    end
  end
end
