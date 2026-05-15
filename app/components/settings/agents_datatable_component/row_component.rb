module Settings
  class AgentsDatatableComponent < Datatable::BaseComponent
    class RowComponent < Datatable::RowComponent
      def agent
        record
      end

      def delete_action
        return unless delete_action?

        action_button(
          agent_path(agent),
          label_key: :label_delete,
          icon_class: "icon-[lucide--trash-2]",
          method: :delete,
          button_class: "btn btn-ghost btn-xs btn-square",
          form_data: {
            turbo_confirm: t(:confirm_delete_agent),
            turbo_stream: true
          }
        )
      end

      def delete_action?
        !agent.builtin?
      end

      def edit_action
        action_link(
          edit_agent_path(agent),
          label_key: :label_edit,
          icon_class: "icon-[lucide--square-pen]",
          link_class: "btn btn-ghost btn-xs btn-square",
          data: { turbo_stream: true }
        )
      end

      def mcp_servers_text
        return "—" if agent.mcp_servers.empty?

        agent.mcp_servers.map(&:name).sort.join(", ")
      end

      def model_text
        return "—" unless agent.model

        "#{agent.model.provider} / #{agent.model.model_id}"
      end

      def row_class
        helpers.class_names("transition-opacity", "opacity-45" => !agent.active?)
      end

      def thinking_text
        return "—" if agent.thinking_effort.blank?

        [ agent.thinking_effort, agent.thinking_budget ].compact.join(" / ")
      end
    end
  end
end
