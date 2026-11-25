module AI
  module Tools
    class RunWorkspaceTask < Tool
      POLL_INTERVAL = 1
      REQUEST_TIMEOUT = 8_000
      STATUSES = %w[queued running completed failed].freeze
      EVENT_KINDS = %w[status tool_call tool_result result error].freeze

      description "Carry out the delegated task in the connected workspace. The runner can inspect and change project files and run commands in an isolated project environment."

      def initialize(chat, run)
        super(chat)
        @run = run
      end

      def name
        "run_workspace_task"
      end

      def execute
        snapshot = with_client { |client| await_workspace_result(client) }
        fail! (snapshot["error"].presence || "The local workspace task failed.") if snapshot["status"] == "failed"

        result = snapshot["result"].presence || fail!("The local workspace runner returned an empty result.")
        { status: "completed", result:, workspace_run_id: @run.workspace_run_id }
      end

      private

      def workspace_server
        return unless @run.local_workspace? && current_user.admin?

        @run.agent&.mcp_servers&.workspace_runner&.active&.find_by(transport_type: %w[streamable_http streamable])
      end

      def with_client
        server = workspace_server
        fail! "The local workspace runner is disconnected." unless server

        client = RubyLLM::MCP::Client.new(**server.to_mcp_config, start: false, request_timeout: REQUEST_TIMEOUT)
        client.start
        yield client
      rescue RubyLLM::MCP::Errors::BaseError, ArgumentError => error
        Rails.logger.warn("[AgentRun #{@run.id}] Workspace runner connection failed: #{error.class}")
        fail! connection_error_message(error)
      ensure
        stop_client(client)
      end

      def connection_error_message(error)
        case error
        when RubyLLM::MCP::Errors::AuthenticationRequiredError
          return "The local workspace runner rejected access. Check the configured runner credentials."
        when RubyLLM::MCP::Errors::TransportError
          if [401, 403].include?(error.code)
            return "The local workspace runner rejected access. Check the connector's credentials and access settings."
          end
        when RubyLLM::MCP::Errors::TimeoutError
          return "The local workspace runner did not respond in time."
        end

        "The local workspace runner could not be reached."
      end

      def stop_client(client)
        client&.stop
      rescue StandardError => error
        Rails.logger.warn("[AgentRun #{@run.id}] Workspace runner disconnect failed: #{error.class}")
      end

      def await_workspace_result(client)
        start_task = client.tool("start_task")
        get_task = client.tool("get_task")
        fail! "The local workspace runner does not provide the required task tools." unless start_task && get_task

        timeout = ENV.fetch("WORKSPACE_RUNNER_POLL_TIMEOUT", "180").to_i.clamp(1, 1_800)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        request_id = "zoe-#{@run.id}-#{@run.created_at.to_f}"
        conversation_id = verify_workspace_conversation(get_task)
        arguments = { task: @run.task, request_id:, conversation_id: }.compact
        snapshot = record_snapshot(fetch_snapshot(start_task, **arguments))
        until snapshot["status"].in?(%w[completed failed])
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          fail! "Timed out waiting for the local workspace runner." unless remaining.positive?

          sleep([ POLL_INTERVAL, remaining ].min)
          snapshot = record_snapshot(fetch_snapshot(get_task, run_id: @run.workspace_run_id, after: @run.workspace_sequence))
        end
        snapshot
      end

      def verify_workspace_conversation(get_task)
        conversation = @run.agent_conversation
        previous = conversation.runs.where(id: ...@run.id).where.not(workspace_run_id: nil).order(id: :desc).first
        if previous
          snapshot = fetch_snapshot(get_task, run_id: previous.workspace_run_id, after: previous.workspace_sequence)
          fail! "The local workspace runner returned a different task." if snapshot["run_id"] != previous.workspace_run_id

          verify_workspace_link!(snapshot)
          if snapshot["status"].in?(%w[queued running])
            fail! "The local workspace runner is still handling the previous request. Retry after it finishes."
          end
        elsif conversation.workspace_conversation_id.present?
          fail! "The previous local workspace history is unavailable."
        end

        conversation.reload.workspace_conversation_id
      end

      def fetch_snapshot(tool, **arguments)
        response = tool.execute(**arguments)
        if response.is_a?(Hash) && (error = response[:error].presence || response["error"].presence)
          fail! error
        end

        snapshot = response.is_a?(Hash) ? response.deep_stringify_keys : JSON.parse(response.to_s)
        fail! "The local workspace runner returned an invalid status." unless valid_snapshot?(snapshot)

        snapshot
      rescue JSON::ParserError
        fail! "The local workspace runner returned an invalid status."
      end

      def record_snapshot(snapshot)
        if @run.workspace_run_id && @run.workspace_run_id != snapshot["run_id"]
          fail! "The local workspace runner returned a different task."
        end
        verify_workspace_link!(snapshot, link: false)
        @run.record_workspace_update!(
          workspace_run_id: snapshot.fetch("run_id"),
          workspace_status: snapshot.fetch("status"),
          workspace_events: snapshot.fetch("events")
        )
        verify_workspace_link!(snapshot)
        snapshot
      end

      def verify_workspace_link!(snapshot, link: true)
        conversation = @run.agent_conversation
        identity = {
          workspace_runner_id: snapshot.fetch("runner_id"),
          workspace_conversation_id: snapshot.fetch("conversation_id")
        }
        if conversation.workspace_conversation_id.present?
          unless identity.all? { |attribute, value| conversation.public_send(attribute) == value }
            fail! "This conversation belongs to a different local workspace runner."
          end
        elsif link
          conversation.update!(identity)
        end
      end

      def valid_snapshot?(snapshot)
        return false unless snapshot.is_a?(Hash)
        return false unless %w[run_id runner_id conversation_id].all? { |key| snapshot[key].is_a?(String) && snapshot[key].present? }

        events = snapshot["events"]
        snapshot["status"].in?(STATUSES) && events.is_a?(Array) && events.all? do |event|
          event.is_a?(Hash) && event["sequence"].is_a?(Integer) && event["type"].in?(EVENT_KINDS) &&
            event.fetch("details", {}).is_a?(Hash)
        end
      end
    end
  end
end
