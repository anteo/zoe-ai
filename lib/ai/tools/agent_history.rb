module AI
  module Tools
    class AgentHistory < Tool
      PAGE_SIZE = 10

      description <<~TEXT.squish
        Find prior specialist conversations for this user and Zoe across chats. Search by a literal
        fragment of the agent name, task or result, or omit query to list recent conversations.
        Pass conversation_id to read the tasks and answers, or give that ID to delegate_task to continue.
      TEXT

      params do
        string :query, description: "Optional search text for listing conversations", required: false
        integer :conversation_id, description: "Read the turns in this specialist conversation", required: false
        integer :before_run_id, description: "Pagination cursor returned as next_before_run_id", required: false
      end

      def name
        "agent_history"
      end

      def execute(query: nil, conversation_id: nil, before_run_id: nil)
        conversations = ::AgentConversation.for_chat_identity(chat)
        if conversation_id
          conversation = conversations.find_by(id: conversation_id)
          fail! "Agent conversation unavailable." unless conversation
          turns, cursor = page(conversation.runs, before_run_id)
          history = turns.reverse.map do |run|
            run.slice(:id, :agent_name, :task, :result, :error, :status, :created_at)
          end
          return JSON.generate(conversation_id: conversation.id, turns: history, next_before_run_id: cursor)
        end

        runs = ::AgentRun.where(agent_conversation_id: conversations.select(:id))
        if query.present?
          matches = runs.where("task ILIKE :q OR result ILIKE :q OR agent_name ILIKE :q",
                               q: "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
          runs = runs.where(agent_conversation_id: matches.select(:agent_conversation_id))
        end
        latest_ids = runs.group(:agent_conversation_id).select("MAX(agent_runs.id)")
        recent, cursor = page(::AgentRun.where(id: latest_ids), before_run_id)
        summaries = recent.map do |run|
          { conversation_id: run.agent_conversation_id, agent: run.agent_name, last_task: run.task.truncate(300),
            last_run_id: run.id, status: run.status, local_workspace: run.local_workspace?, created_at: run.created_at }
        end
        JSON.generate(conversations: summaries, next_before_run_id: cursor)
      end

      private

      def page(scope, before_run_id)
        scope = scope.where("agent_runs.id < ?", before_run_id) if before_run_id
        rows = scope.reorder(id: :desc).limit(PAGE_SIZE + 1).to_a
        items = rows.first(PAGE_SIZE)
        [ items, (items.last.id if rows.size > PAGE_SIZE) ]
      end
    end
  end
end
