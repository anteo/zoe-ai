require "test_helper"

class AgentHistoryTest < ActiveSupport::TestCase
  fixtures :characters, :characters_users, :chats, :users

  setup do
    @chat = chats(:anton_with_zoe)
    @agent = Agent.create!(name: "Archivist")
    @tool = AI::Tools::AgentHistory.new(@chat)
  end

  test "finds a dialog by an older turn and returns its turns in order across chats" do
    conversation = dialog(@chat)
    first = add_run(@chat, conversation, "Inventory 75%")
    next_chat = @chat.dup.tap(&:save!)
    second = add_run(next_chat, conversation, "Expand the list")
    add_run(next_chat, dialog(next_chat), "Inventory 750")

    items = lookup(query: "75%").fetch("conversations")
    assert_equal [ conversation.id ], items.pluck("conversation_id")
    assert_equal second.task, items.first.fetch("last_task")
    assert_equal [ first.id, second.id ], lookup(conversation_id: conversation.id).fetch("turns").pluck("id")
  end

  test "scopes discovery and direct lookup to the current identity" do
    other = @chat.dup
    other.partner = Character.create!(name: "Another partner", ai: true)
    other.save!
    hidden = dialog(other)
    add_run(other, hidden, "Private assignment")
    assert_empty lookup.fetch("conversations")
    assert @tool.call(conversation_id: hidden.id).key?(:error)
  end

  test "reports active calls and matches recent results to older calls" do
    conversation = dialog(@chat)
    run = @chat.agent_runs.create!(agent_conversation: conversation, agent: @agent, agent_name: @agent.name,
                                  task: "Run checks", status: "running", workspace_status: "running")
    run.events.create!(kind: "tool_call", data: { tool: "run_workspace_task", tool_call_id: "workspace-#{run.id}" })
    run.events.create!(kind: "tool_call", data: { source: "workspace", tool: "run_command", tool_call_id: "build",
                                                  arguments: { command: "make build" } })
    run.events.create!(kind: "tool_call", data: { source: "workspace", tool: "run_command", tool_call_id: "check",
                                                  arguments: { command: "make check", input: "private input" } })
    AI::Tools::AgentHistory::EVENT_LIMIT.times do
      run.events.create!(kind: "status", data: { status: "running" })
    end
    run.events.create!(kind: "tool_result", message: "private output",
                       data: { source: "workspace", tool: "run_command", tool_call_id: "check", success: false, exit_status: 2 })
    run.events.create!(kind: "assistant", message: "internal transcript")

    turn = lookup(conversation_id: conversation.id).fetch("turns").sole
    assert_equal [ "build" ], turn.fetch("active_calls").pluck("tool_call_id")
    assert_equal "make build", turn.fetch("active_calls").sole.dig("arguments", "command")
    events = turn.fetch("recent_events")
    assert_equal AI::Tools::AgentHistory::EVENT_LIMIT, events.size
    result = events.last
    assert_equal "tool_result", result.fetch("kind")
    assert_equal false, result.fetch("success")
    assert_equal 2, result.fetch("exit_status")
    assert_equal({ "command" => "make check" }, result.fetch("arguments"))
    assert_not_includes turn.to_json, "private output"
    assert_not_includes turn.to_json, "internal transcript"

    run.update!(status: "failed", error: "Interrupted")
    assert_empty lookup(conversation_id: conversation.id).fetch("turns").sole.fetch("active_calls")
  end

  test "older pages of turns use an exclusive cursor" do
    conversation = dialog(@chat)
    first = add_run(@chat, conversation, "First")
    AI::Tools::AgentHistory::PAGE_SIZE.times { |i| add_run(@chat, conversation, "Task #{i}") }
    recent = lookup(conversation_id: conversation.id)
    older = lookup(conversation_id: conversation.id, before_run_id: recent.fetch("next_before_run_id"))
    assert_equal [ first.id ], older.fetch("turns").pluck("id")
    assert_nil older.fetch("next_before_run_id")
  end

  test "lists unique dialogs in order of their latest run on each page" do
    oldest = dialog(@chat)
    add_run(@chat, oldest, "Old note")
    others = Array.new(AI::Tools::AgentHistory::PAGE_SIZE) do |i|
      dialog(@chat).tap { |item| add_run(@chat, item, "Note #{i}") }
    end
    add_run(@chat, oldest, "Follow-up")

    first_page = lookup
    assert_equal oldest.id, first_page.fetch("conversations").first.fetch("conversation_id")
    last_page = lookup(before_run_id: first_page.fetch("next_before_run_id"))
    assert_equal [ others.first.id ], last_page.fetch("conversations").pluck("conversation_id")
    assert_nil last_page.fetch("next_before_run_id")
  end

  private

  def lookup(**args)
    JSON.parse(@tool.call(args))
  end

  def dialog(chat)
    AgentConversation.create!(user: chat.user, character: chat.character, partner: chat.partner,
                              agent: @agent, agent_name: @agent.name)
  end

  def add_run(chat, conversation, task)
    chat.agent_runs.create!(agent_conversation: conversation, agent: @agent, agent_name: @agent.name,
                            task:, status: "completed", result: "Finished")
  end
end
