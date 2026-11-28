module Chats
  class ChatComponent < ApplicationComponent
    attr_reader :chat, :dom_id, :path_for_conversation

    def self.active_runs_id(chat_id) = "active-agent-runs-#{chat_id}"
    def self.placeholder_id(chat_id) = "message-placeholder-slot-#{chat_id}"

    def initialize(chat:, read_only: false, dom_id: "chat-messages", messages: nil, agent_runs: nil, path_for_conversation: nil)
      @chat = chat
      @read_only = read_only
      @dom_id = dom_id
      @messages = messages
      @agent_runs = agent_runs
      @path_for_conversation = path_for_conversation
    end

    def messages
      records = @messages || chat.messages_association.visible.order(:created_at, :id)
      records.flat_map do |message|
        self.class.display_messages(message)
      end
    end

    def timeline
      entries = messages + agent_runs.reject(&:running?)
      entries.sort_by.with_index do |entry, index|
        entry.is_a?(AgentRun) ? [ entry.timeline_at, 1, entry.id ] : [ entry.created_at, 0, index ]
      end
    end

    def active_runs
      agent_runs.select(&:running?).sort_by { |run| [ run.created_at, run.id ] }
    end

    def pending_messages
      return [] unless new?

      PendingMessage.for_delivery(user: chat.user, recipient: current_character, partner: current_partner)
                    .with_attached_attachments
                    .flat_map { self.class.display_messages(it) }
    end

    def agent_runs
      @agent_runs ||= begin
        chat.agent_runs.reconcile_interrupted!
        chat.agent_runs.shown_in_chat.preload(:progress_events).to_a
      end
    end

    def new?
      chat.new_record? && @messages.nil?
    end

    def show_typing_indicator?
      return false if chat.new_record?
      return true if RespondJob.waiting_for_reply?(chat, delegated_job_ids: agent_runs.map(&:respond_job_id))
      return false unless TypeSentenceJob.running_for?(chat)

      trigger_message_id = chat.latest_user_message_id
      agent_runs.none? { |run| run.running? && run.trigger_message_id == trigger_message_id }
    end

    def read_only?
      @read_only
    end

    def current_character
      @chat.character
    end

    def current_partner
      @chat.partner
    end

    def draft_empty_state_id
      "draft-chat-empty-state"
    end

    def draft_messages_id
      "draft-chat-pending-messages"
    end

    def self.display_messages(message)
      return [ message ] unless message.assistant? && message.content.present?

      chunks = AI::SentenceSplitter.new(message.content).chunks
      return [ message ] if chunks.size <= 1

      chunks.each_with_index.map do |chunk, index|
        if index.zero?
          message.tap { |display_message| display_message.content = chunk.to_s }
        else
          message.dup.tap do |extra_message|
            extra_message.created_at = message.created_at
            extra_message.content = chunk.to_s
          end
        end
      end
    end
  end
end
