class AgentRun < ApplicationRecord
  belongs_to :chat
  belongs_to :agent, optional: true
  belongs_to :agent_conversation, touch: true
  belongs_to :trigger_message, class_name: "Message", optional: true
  has_many :events, -> { order(:id) }, class_name: "AgentRunEvent", dependent: :delete_all
  has_many :progress_events, -> { where(kind: %w[status tool_call tool_result result error]).order(:id) },
           class_name: "AgentRunEvent"

  enum :status, %w[running completed failed].index_by(&:itself), validate: true
  validate :matches_conversation, on: :create

  def self.reconcile_interrupted!
    running.where.not(respond_job_execution_id: nil).find_each do |run|
      owned = SolidQueue::ClaimedExecution.uncached do
        SolidQueue::ClaimedExecution.exists?(run.respond_job_execution_id)
      end
      next if owned

      run.finish!(error: "The response job stopped before the delegated task finished.")
    end
  end

  def append_event!(kind, message: nil, data: {})
    event = events.create!(kind:, message:, data:)
    broadcast_progress if kind.in?(%w[status tool_call tool_result result error])
    event
  end

  def record_workspace_update!(workspace_run_id:, workspace_status:, workspace_events:)
    updated = with_lock do
      next false unless running?

      new_events = workspace_events.select { |event| event.fetch("sequence") > workspace_sequence }
      new_events.sort_by! { |event| event.fetch("sequence") }
      next false if new_events.empty? && self.workspace_run_id == workspace_run_id && self.workspace_status == workspace_status

      update!(
        workspace_run_id:,
        workspace_status:,
        workspace_sequence: new_events.last&.fetch("sequence") || workspace_sequence
      )
      new_events.each do |event|
        details = event.fetch("details", {}).merge(event.slice("sequence", "at"))
        events.create!(
          kind: event.fetch("type"),
          message: event["message"],
          data: details.merge("source" => "workspace")
        )
      end
      true
    end
    broadcast_progress if updated
  end

  def finish!(result: nil, error: nil)
    final_status = error.present? ? "failed" : "completed"
    updated = with_lock do
      next false unless running?

      update!(result:, error:, status: final_status, finished_at: Time.current)
      events.create!(
        kind: error.present? ? "error" : "result",
        message: error || result,
        data: { status: final_status }
      )
      true
    end
    broadcast_progress if updated
  end

  private

  def matches_conversation
    return unless agent_conversation && chat

    conversation_identity = agent_conversation.attributes.values_at("user_id", "character_id", "partner_id")
    chat_identity = chat.attributes.values_at("user_id", "character_id", "partner_id")
    return if conversation_identity == chat_identity &&
              agent_conversation.agent_id == agent_id && agent_conversation.local_workspace? == local_workspace?

    errors.add(:agent_conversation, :invalid)
  end

  def broadcast_progress
    AI::AgentRunProgress.broadcast(self)
  end
end
