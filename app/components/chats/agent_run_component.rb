module Chats
  class AgentRunComponent < ApplicationComponent
    attr_reader :run

    def self.frame_id(run_id) = "agent-run-frame-#{run_id}"

    def initialize(chat:, run:, read_only: false, path_for_conversation: nil, frame_response: false)
      @chat = chat
      @run = run
      @read_only = read_only
      @path_for_conversation = path_for_conversation
      @frame_response = frame_response
    end

    def live?
      !@read_only
    end

    def frame_options
      {
        class: "block",
        src: (helpers.agent_run_chat_path(@chat, run_id: run.id) if @chat.persisted? && !@frame_response),
        complete: true,
        refresh: "morph",
        data: { agent_run_frame: true, chat_order: timeline_order }
      }
    end

    def frame_id
      self.class.frame_id(run.id)
    end

    def card_id
      [ ("history" unless live?), "agent-run", run.id ].compact.join("-")
    end

    def timeline_order
      "#{run.timeline_at.utc.iso8601(6)}/1/#{format('%020d', run.id)}"
    end

    def conversation_path
      return if run.local_workspace? && !@chat.user.admin?

      @path_for_conversation&.call(run) || helpers.agent_conversation_chat_path(@chat, run.agent_conversation_id)
    end

    def phase
      return run.status unless run.running?

      last_status = run.progress_events.reverse_each.find { |event| event.kind == "status" }&.data&.[]("status")
      case run.workspace_status || last_status
      when "queued" then "queued"
      when "completed" then "preparing_result"
      else run.status
      end
    end
  end
end
