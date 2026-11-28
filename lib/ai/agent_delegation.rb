module AI
  class AgentDelegation
    class Error < RubyLLM::Error; end

    def initialize(chat)
      @chat = chat
    end

    def dispatch(task:, profile:, conversation: nil, project: nil)
      trigger_message_id = chat.agent_run_trigger_message_id || chat.latest_user_message_id

      conversation ||= ::AgentConversation.new(
        user: chat.user, character: chat.character, partner: chat.partner,
        agent: profile, agent_name: profile.name,
        local_workspace: profile.workspace_backend.present? || profile.mcp_servers.workspace_runner.exists?
      )
      run = create_run(conversation, task:, trigger_message_id:)
      perform_run(run, profile, project:)
      {
        conversation_id: conversation.id, run_id: run.id, agent: run.agent_name,
        status: run.status, result: run.result, error: run.error
      }.compact
    end

    private

    attr_reader :chat

    def create_run(conversation, task:, trigger_message_id:)
      conversation.runs.reconcile_interrupted! if conversation.persisted?
      chat.with_lock do
        owner = chat.agent_run_job_owner || {}
        response_stopped = if (execution_id = owner[:respond_job_execution_id])
          SolidQueue::ClaimedExecution.uncached do
            !SolidQueue::ClaimedExecution.exists?(id: execution_id, cancelled: false)
          end
        end
        if response_stopped || (trigger_message_id && chat.stale_trigger_message?(trigger_message_id))
          raise Error, "The message that requested this task is no longer current."
        end

        conversation.save! if conversation.new_record?
        conversation.with_lock do
          if conversation.runs.running.exists?
            raise Error, "The agent is still handling a request in this conversation. Retry after it finishes."
          end

          conversation.runs.create!(
            chat:, agent: conversation.agent, agent_name: conversation.agent.name, task:,
            local_workspace: conversation.local_workspace?, trigger_message_id:,
            **owner
          )
        end
      end
    end

    def perform_run(run, profile, project:)
      run.append_event!("status", data: { status: "running" })
      run.append_event!("user", message: run.task)
      if run.local_workspace?
        run.finish!(result: run_workspace_task(run, project:))
        return
      end

      llm_chat = profile.chat(chat:)
      llm_chat.with_tools(concurrency: false)
      AgentConversationHistory.new(run).replay_into(llm_chat)
      llm_chat.messages.select { |message| message.role == :system }.each do |message|
        run.append_event!("system", message: message.content.to_s)
      end
      record_messages(llm_chat, run)

      result = llm_chat.ask(run.task).content.to_s.presence
      raise Error, "The agent returned an empty response." if result.blank?

      run.finish!(result:)
    rescue RubyLLM::Error => error
      run.finish!(error: error.message)
    rescue StandardError => error
      Rails.logger.error("[AgentRun #{run.id}] #{error.class}: #{error.message}")
      run.finish!(error: "The delegated agent could not complete the task.")
    end

    def run_workspace_task(run, project:)
      tool = Tools::RunWorkspaceTask.new(chat, run, project:)
      details = { tool: tool.name, tool_call_id: "workspace-#{run.id}" }
      run.append_event!("tool_call", message: tool.name, data: details)
      result = tool.call({})
      run.append_event!("tool_result", message: result.to_json, data: details.merge(success: result[:error].blank?))
      raise Error, result[:error] if result[:error].present?

      result.fetch(:result)
    end

    def record_messages(llm_chat, run)
      tool_call = nil
      llm_chat.before_tool_call do |call|
        tool_call = call
        run.append_event!(
          "tool_call",
          message: call.name,
          data: { tool: call.name, tool_call_id: call.id, arguments: call.arguments }
        )
      end
      llm_chat.after_tool_result do |result|
        payload = result.is_a?(RubyLLM::Tool::Halt) ? result.content : result
        error = payload[:error] || payload["error"] if payload.is_a?(Hash)
        run.append_event!(
          "tool_result",
          message: payload.is_a?(Hash) ? payload.to_json : history_content(payload),
          data: { tool: tool_call.name, tool_call_id: tool_call.id, success: error.blank? }
        )
      end
      llm_chat.after_message do |message|
        next unless message.role == :assistant

        run.append_event!(
          "assistant",
          message: history_content(message.content),
          data: message.to_h.except(:role, :content, :tool_calls).merge(
            tool_calls: message.tool_calls&.values&.map(&:to_h)
          ).compact
        )
      end
    end

    def history_content(content)
      case content
      when RubyLLM::Content then content.text.to_s
      when RubyLLM::Content::Raw then content.value.to_json
      else content.to_s
      end
    end
  end
end
