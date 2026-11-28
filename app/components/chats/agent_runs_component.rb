module Chats
  class AgentRunsComponent < ApplicationComponent
    attr_reader :runs

    def self.frame_id(chat_id, trigger_message_id)
      [ "agent-runs", chat_id, trigger_message_id ].compact.join("-")
    end

    def initialize(chat:, trigger_message_id: nil, runs: [], read_only: false, fetch: false)
      @chat = chat
      @trigger_message_id = trigger_message_id
      @runs = runs
      @read_only = read_only
      @fetch = fetch
    end

    def render?
      live? || runs.any?
    end

    def live?
      !@read_only
    end

    def frame_options
      url = helpers.agent_runs_chat_path(@chat, message_id: @trigger_message_id)
      {
        src: (url if @fetch),
        refresh: "morph",
        data: { agent_runs_url: url }
      }
    end

    def frame_id
      self.class.frame_id(@chat.id, @trigger_message_id)
    end

    def card_id(run)
      [ ("history" unless live?), "agent-run", run.id ].compact.join("-")
    end

    def conversation_path(run)
      return if run.local_workspace? && !@chat.user.admin?

      helpers.agent_conversation_chat_path(@chat, run.agent_conversation_id)
    end

    def phase(run)
      return run.status unless run.running?

      last_status = run.progress_events.reverse_each.find { |event| event.kind == "status" }&.data&.[]("status")
      case run.workspace_status || last_status
      when "queued" then "queued"
      when "completed" then "preparing_result"
      else run.status
      end
    end

    def status_class(run)
      case run.status
      when "completed" then "badge-success"
      when "failed" then "badge-error"
      else "badge-info"
      end
    end
  end
end
