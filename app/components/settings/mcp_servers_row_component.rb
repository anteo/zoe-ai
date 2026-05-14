module Settings
  class MCPServersRowComponent < Datatable::RowComponent
    def initialize(record:, datatable: nil, in_progress: false)
      super(record:, datatable:)
      @in_progress = in_progress
    end

    def mcp_server
      record
    end

    def in_progress?
      @in_progress
    end

    def delete_action
      action_button(
        mcp_server_path(mcp_server),
        label_key: :label_delete,
        icon_class: "icon-[lucide--trash-2]",
        method: :delete,
        button_class: "btn btn-ghost btn-xs btn-square",
        form_data: {
          turbo_confirm: t(:confirm_delete_mcp_server),
          turbo_stream: true
        }
      )
    end

    def edit_action
      action_link(
        edit_mcp_server_path(mcp_server),
        label_key: :label_edit,
        icon_class: "icon-[lucide--square-pen]",
        link_class: "btn btn-ghost btn-xs btn-square",
        data: { turbo_stream: true }
      )
    end

    def status_action
      return loading_action_button if in_progress?

      mcp_server.active? ? stop_action : start_action
    end

    def status_text_class
      helpers.class_names("text-xs", "text-error" => mcp_server.last_error.present?)
    end

    private

    def start_action
      action_button(
        start_mcp_server_path(mcp_server),
        label_key: :label_start,
        icon_class: "icon-[lucide--play]",
        method: :patch,
        button_class: "btn btn-ghost btn-xs btn-square text-success",
        form_data: { turbo_stream: true }
      )
    end

    def stop_action
      action_button(
        stop_mcp_server_path(mcp_server),
        label_key: :label_stop,
        icon_class: "icon-[lucide--pause]",
        method: :patch,
        button_class: "btn btn-ghost btn-xs btn-square text-error",
        form_data: { turbo_stream: true }
      )
    end
  end
end
