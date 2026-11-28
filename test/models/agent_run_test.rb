require "test_helper"

class AgentRunTest < ActiveSupport::TestCase
  fixtures :characters, :characters_users, :chats, :users

  test "reconciles an interrupted attempt without expiring a claimed run or a new attempt" do
    chat = chats(:anton_with_zoe)
    response = RespondJob.new(chat, chat.latest_user_message_id)
    job = SolidQueue::Job.create!(active_job_id: response.job_id, class_name: response.class.name,
                                  queue_name: response.queue_name, arguments: response.serialize)
    process = SolidQueue::Process.create!(
      name: "test-worker", kind: "Worker", pid: Process.pid, last_heartbeat_at: Time.current
    )
    claim = SolidQueue::ClaimedExecution.create!(job:, process:)
    interrupted_run = create_run(chat, claim:)
    standalone_run = create_run(chat)
    interrupted_run.update!(created_at: 1.day.ago)

    chat.agent_runs.reconcile_interrupted!
    assert_predicate interrupted_run.reload, :running?

    claim.failed_with(RuntimeError.new("Worker exited"))
    new_claim = SolidQueue::ClaimedExecution.create!(job:, process:)
    new_run = create_run(chat, claim: new_claim)

    chat.agent_runs.reconcile_interrupted!
    assert_predicate interrupted_run.reload, :failed?
    assert interrupted_run.finished_at
    assert_equal ["error"], interrupted_run.events.pluck(:kind)
    assert_predicate new_run.reload, :running?
    assert_predicate standalone_run.reload, :running?

    chat.agent_runs.reconcile_interrupted!
    assert_equal 1, interrupted_run.events.count
  end

  private

  def create_run(chat, claim: nil)
    conversation = AgentConversation.create!(
      user: chat.user, character: chat.character, partner: chat.partner, agent_name: "Workspace Assistant"
    )
    chat.agent_runs.create!(
      agent_conversation: conversation,
      agent_name: "Workspace Assistant",
      task: "Summarize the workspace",
      respond_job_id: claim&.job&.active_job_id,
      respond_job_execution_id: claim&.id
    )
  end
end
