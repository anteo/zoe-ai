module AI
  module Tools
    class DelegateTask < Tool
      description <<~TEXT.squish
        Choose an available specialist when the user's goal or the conversation context calls for
        its capabilities, even when the user does not mention an agent. State the goal at a high level,
        include relevant context and the user's constraints, and describe what counts as done.
        The agent chooses the commands and steps using the project instructions. Preserve exact commands the user supplied.
        Ask for a verified final outcome for long-running actions. Zoe already runs the delegation in the background
        and posts its result automatically while the chat remains available.
        Use agent_history to check an existing dialog's status or findings. Provide the agent for a new conversation or
        conversation_id to continue a related task. If a project is required and its name is unknown,
        omit it to discover available projects. Retry with the matching name or ask the user if ambiguous.
        If delegation fails, explain the returned error.
      TEXT

      params do
        string :task, description: "The high-level goal, relevant context, user constraints, and expected outcome", required: true
        string :agent, description: "Agent key, id:NUMBER, or exact name from the available profiles. Required for a new conversation.", required: false
        integer :conversation_id, description: "Agent conversation ID for a follow-up. Omit when selecting an agent for a new conversation.", required: false
        string :project, description: "Workspace project name, if required by the selected agent. Existing workspace conversations can reuse their project.", required: false
      end

      def name
        "delegate_task"
      end

      def description
        profiles = ::Agent.delegatable(current_user).order(:id).pluck(:id, :key, :name, :description).map do |id, key, name, description|
          { agent: key || "id:#{id}", name:, description: }
        end
        "#{super} Available agents: #{profiles.to_json}."
      end

      def execute(task:, agent: nil, conversation_id: nil, project: nil)
        fail! "Provide a task to delegate." unless task.is_a?(String) && task.strip.present?

        if conversation_id.nil?
          fail! "Select an available agent for a new conversation." unless agent.is_a?(String) && agent.present?

          profile = find_profile(agent)
        else
          fail! "Provide only the conversation ID to continue an existing conversation." unless agent.nil?

          conversation = find_conversation(conversation_id)
          profile = ::Agent.active.custom.find_by(id: conversation.agent_id)
        end
        fail! "Delegation profile is unavailable." unless profile

        if project && (!project.is_a?(String) || project.blank?)
          fail! "Provide a workspace project name."
        end
        if profile.workspace_backend.present? && project.nil? && conversation&.workspace_conversation_id.nil?
          return workspace_projects(profile)
        end

        background = chat.agent_run_job_owner.present?
        result = JSON.generate(AgentDelegation.new(chat).dispatch(task:, profile:, conversation:, project:, background:))
        background ? halt(result) : result
      end

      private

      def workspace_projects(profile)
        snapshot = WorkspaceRunnerConnection.new(chat, profile).open do |client|
          list = client.tool("list_projects")
          fail! "Provide the workspace project name or update the runner to discover projects." unless list

          result = list.execute
          result.is_a?(Hash) ? result.deep_stringify_keys : JSON.parse(result.to_s)
        end
        projects = snapshot["projects"] if snapshot.is_a?(Hash)
        fail! "The workspace runner returned an invalid project list." unless projects.is_a?(Array) && projects.all?(String)

        JSON.generate(needs_project: true, projects:, truncated: snapshot["truncated"])
      rescue WorkspaceRunnerConnection::Error => error
        fail! error.message
      rescue JSON::ParserError
        fail! "The workspace runner returned an invalid project list."
      end

      def find_profile(selection)
        profiles = ::Agent.delegatable(current_user)
        if (id = selection[/\Aid:(\d+)\z/, 1])
          profiles.find_by(id:)
        else
          profiles.find_by(key: selection) || profiles.find_by(name: selection)
        end
      end

      def find_conversation(id)
        if id.is_a?(Integer) && id.positive?
          conversation = ::AgentConversation.for_chat_identity(chat).find_by(id:)
        end
        conversation || fail!("Agent conversation is unavailable.")
      end
    end
  end
end
