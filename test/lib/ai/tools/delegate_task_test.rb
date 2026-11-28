require "test_helper"

class DelegateTaskTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  fixtures :characters, :characters_users, :chats, :users

  StubModel = Struct.new(:id)
  StubTool = Struct.new(:handler) do
    def execute(**arguments)
      handler.call(**arguments)
    end
  end

  class StubProvider
    attr_reader :requests

    def initialize(responses)
      @responses = responses
      @requests = []
    end

    def slug = "test"
    def connection = nil

    def complete(messages, tools:, tool_prefs:, **options)
      @requests << { messages: messages.dup, tools: tools.keys, choice: tool_prefs[:choice], **options }
      response = @responses.shift
      raise response if response.is_a?(Exception)

      response
    end
  end

  setup do
    @chat = chats(:anton_with_zoe)
    @profile = Agent.create!(name: "Project researcher", description: "Inspects project documents.",
                             instructions: "Carry out the specific job requested.")
  end

  test "queues a workspace delegation and polls it after a newer chat message" do
    @chat.user.update!(admin: true)
    connect_workspace_runner
    trigger = @chat.messages.create!(role: "user", content: "Run a long task")
    @chat.agent_run_trigger_message_id = trigger.id
    @chat.agent_run_job_owner = { respond_job_id: SecureRandom.uuid }
    calls = []
    client = stub_runner_client(
      start_task: StubTool.new(lambda do |**arguments|
        calls << [:start, arguments]
        runner_content("queued", [runner_event(1, "status", "Queued", status: "queued")])
      end),
      get_task: StubTool.new(lambda do |**arguments|
        calls << [:poll, arguments]
        runner_content("completed", [], result: "The deployment finished.")
      end)
    )

    AI::AgentRunProgress.stub(:broadcast, nil) do
      RubyLLM::MCP::Client.stub(:new, client) do
        queued = tool.call(agent: @profile.name, task: "Perform deployment")
        assert_instance_of RubyLLM::Tool::Halt, queued
        detail = JSON.parse(queued.content)
        run = @chat.agent_runs.find(detail.fetch("run_id"))
        assert_equal "queued", detail.fetch("status")
        assert_empty calls
        assert_equal trigger.id, run.trigger_message_id

        perform_enqueued_jobs(only: AgentRunJob, at: Time.current)
        assert_equal "runner-1", run.reload.workspace_run_id
        assert_predicate run, :running?
        assert_equal [:start], calls.map(&:first)

        newer = @chat.messages.create!(role: "user", content: "Answer a different question")
        travel 3.seconds do
          perform_enqueued_jobs(only: AgentRunJob, at: Time.current)
          assert_predicate run.reload, :completed?
          assert_equal "The deployment finished.", run.result
          assert_equal [:poll, { run_id: "runner-1", after: 1 }], calls.last
          assert_equal [:start, :poll], calls.map(&:first)

          assert_difference -> { @chat.messages.where(role: "assistant").count }, 1 do
            perform_enqueued_jobs(only: ReportAgentRunJob)
          end
          reply = @chat.messages.where(role: "assistant").order(:id).last
          assert_operator reply.id, :>, newer.id
          refute reply.memorize?
          assert run.reload.reported_at
          assert_no_difference -> { @chat.messages.count } do
            ReportAgentRunJob.perform_now(run.id)
          end
        end
      end
    end
  end

  test "stores a separate delegation transcript and does not append to the conversation" do
    @chat.messages.create!(role: "user", content: "A previous turn with private context")
    trigger = @chat.messages.create!(role: "user", content: "Please delegate this")
    original_message_ids = @chat.messages.order(:id).ids
    snapshot = nil

    with_provider(assistant_message("A delegated answer")) do |provider|
      snapshot = delegate(agent: @profile.name, task: "Explain the sorting algorithm.")
      assert_equal %i[system user], provider.requests.first[:messages].map(&:role)
      assert_equal "Explain the sorting algorithm.", provider.requests.first[:messages].last.content
    end

    run = @chat.agent_runs.find(snapshot.fetch("run_id"))
    assert_equal run.agent_conversation_id, snapshot.fetch("conversation_id")
    assert_equal "completed", snapshot.fetch("status")
    assert_equal "A delegated answer", run.result
    assert_equal trigger.id, run.trigger_message_id
    assert_equal %w[status user system assistant result], run.events.pluck(:kind)
    assert_equal original_message_ids, @chat.messages.order(:id).ids
    assert_equal 0, @chat.facts.count
  end

  test "resumes the original specialist and its tool transcript in another matching chat" do
    custom = Agent.create!(name: "Reviewer", instructions: "Review the original material")
    conversation = create_conversation(agent: custom)
    first = create_turn(conversation, task: "Check the document version.")
    first.append_event!("assistant", message: "")
    first.append_event!("tool_call", data: { tool: "inspect_version", tool_call_id: "lookup-1", arguments: { path: "project" } })
    first.append_event!("tool_result", message: "Document revision 87", data: { tool_call_id: "lookup-1" })
    first.append_event!("assistant", message: "Revision 87 is current.")
    first.finish!(result: "Revision 87 is current.")
    unrelated = create_turn(create_conversation, task: "Unrelated private task")
    unrelated.finish!(result: "Unrelated result")

    later_chat = matching_chat
    with_provider(assistant_message("The affected version is 87.")) do |provider|
      result = delegate(chat: later_chat, task: "Which version was it?", conversation_id: conversation.id)
      assert_equal conversation.id, result.fetch("conversation_id")
      refute_equal first.id, result.fetch("run_id")
      next_run = later_chat.agent_runs.find(result.fetch("run_id"))
      assert_equal custom, next_run.agent
      assert_equal [first.id, next_run.id], conversation.runs.order(:id).ids

      messages = provider.requests.sole.fetch(:messages)
      assert_equal %i[system user assistant tool assistant user], messages.map(&:role)
      assert_equal "Check the document version.", messages[1].content
      assert_equal "inspect_version", messages[2].tool_calls.fetch("lookup-1").name
      assert_equal({ "path" => "project" }, messages[2].tool_calls.fetch("lookup-1").arguments)
      assert_equal "lookup-1", messages[3].tool_call_id
      assert_equal "Document revision 87", messages[3].content
      assert_equal "Revision 87 is current.", messages[4].content
      assert_equal "Which version was it?", messages[5].content
    end
  end

  test "bounds oversized history and tells the specialist that context was omitted" do
    conversation = create_conversation
    first = create_turn(conversation, task: "Inspect the document.")
    first.append_event!("assistant", message: "")
    first.append_event!("tool_call", data: { tool: "read_document", tool_call_id: "read-1" })
    first.append_event!("tool_result", message: "X" * 200_000, data: { tool_call_id: "read-1" })
    first.finish!(result: "It documents version 5.")

    with_provider(assistant_message("It was version 5.")) do |provider|
      result = delegate(task: "Which version?", conversation_id: conversation.id)
      assert_equal "completed", result.fetch("status")
      messages = provider.requests.sole.fetch(:messages)
      assert_equal %i[system user assistant user], messages.map(&:role)
      assert_match(/omitted/, messages[0].content)
      assert_includes messages[1].content, "Inspect the document."
      assert_includes messages[2].content, "It documents version 5."
    end
  end

  test "uses the original dialog identity and settings and prevents overlapping turns" do
    conversation = create_conversation
    create_turn(conversation, task: "A request still in progress")
    other_user = User.create!(email: "other-delegations@example.com", password: "password123",
                              first_name: "Other", confirmed_at: Time.current)
    other_partner = Character.create!(name: "Another AI", ai: true)
    other_character = Character.create!(name: "Another identity")
    other_chats = [matching_chat(user: other_user), matching_chat(partner: other_partner),
                   matching_chat(character: other_character)]
    other_profile = Agent.create!(name: "Other profile")
    arguments = { task: "Continue", conversation_id: conversation.id }

    assert_no_difference -> { conversation.runs.count } do
      other_chats.each do |other_chat|
        assert_match(/unavailable/, tool(other_chat).call(arguments).fetch(:error))
      end
      assert_match(/only the conversation ID/, tool.call(arguments.merge(agent: "id:#{other_profile.id}")).fetch(:error))
      assert_match(/still handling/, tool.call(arguments).fetch(:error))
    end
  end

  test "resolves a custom agent by name and excludes operational agents" do
    custom = Agent.create!(name: "Editor", description: "Revises drafts.", instructions: "Edit the text")
    Agent.create!(name: "Inactive Editor", active: false)
    Agent.find_or_create_by!(key: "extract_facts") do |agent|
      agent.name = "Extract Facts"
      agent.builtin = true
    end

    assert_includes tool.description, { agent: "id:#{custom.id}", name: "Editor", description: "Revises drafts." }.to_json
    refute_includes tool.description, "Edit the text"
    custom.update!(description: "Proofreads articles.")
    assert_includes tool.description, "Proofreads articles."
    refute_includes tool.description, "Revises drafts."
    assert_no_difference("AgentRun.count") { assert tool.call(task: "Review my draft").key?(:error) }
    refute_includes tool.description, "Inactive Editor"
    refute_includes tool.description, "extract_facts"

    with_provider(assistant_message("Edited"), assistant_message("Edited again")) do
      [ "Editor", "id:#{custom.id}" ].each do |selection|
        detail = delegate(task: "Edit a sentence", agent: selection)
        assert_equal custom, AgentRun.find(detail.fetch("run_id")).agent
      end
    end
    assert_equal({ error: "Delegation profile is unavailable." }, tool.call(task: "Collect facts", agent: "extract_facts"))
  end

  test "rejects non-admin local work and handles a disconnected runner" do
    @chat.user.update!(admin: false)
    connect_workspace_runner(active: false)
    refute_includes tool.description, @profile.name
    args = { task: "List my directory", agent: @profile.name }
    assert_no_difference -> { @chat.agent_runs.count } do
      assert tool.call(args).key?(:error)
    end

    @chat.user.update!(admin: true)
    assert_includes tool.description, @profile.description
    detail = delegate(**args)
    assert_equal "failed", detail.fetch("status")
    assert_match(/disconnected/, detail.fetch("error"))
    assert_equal %w[status user tool_call tool_result error], AgentRun.find(detail.fetch("run_id")).events.pluck(:kind)
  end

  test "keeps the stale respond job from starting a new delegation" do
    old_trigger = @chat.messages.create!(role: "user", content: "Old trigger")
    @chat.messages.create!(role: "user", content: "New trigger")
    @chat.agent_run_trigger_message_id = old_trigger.id

    assert_no_difference -> { @chat.agent_runs.count } do
      assert_match(/no longer current/, tool.call(agent: @profile.name, task: "Explain the sorting algorithm.").fetch(:error))
    end
  end

  test "polls the connected runner and records local and nested tool history in order" do
    @chat.user.update!(admin: true)
    connect_workspace_runner
    task = "List the names in the configured workspace."
    starts = []
    polls = []
    client = stub_runner_client(
      start_task: StubTool.new(lambda do |**arguments|
        starts << arguments
        runner_content("queued", [ runner_event(1, "status", "Queued", status: "queued") ])
      end),
      get_task: StubTool.new(lambda do |**arguments|
        polls << arguments
        runner_content("completed", [
          runner_event(1, "status", "Queued", status: "queued"),
          runner_event(2, "tool_call", "Read directory", tool: "list"),
          runner_event(3, "tool_result", "Read 1 file", tool: "list", success: true),
          runner_event(4, "result", "README.md")
        ], result: "README.md")
      end)
    )
    with_provider do |provider|
      RubyLLM::MCP::Client.stub(:new, client) do
        detail = delegate(task:, agent: @profile.name)
        run = AgentRun.find(detail.fetch("run_id"))
        assert_equal "completed", run.status
        assert_equal "completed", run.workspace_status
        assert_equal "runner-1", run.workspace_run_id
        assert_equal "README.md", run.result
        assert_equal %w[status user tool_call status tool_call tool_result result tool_result result],
                     run.events.pluck(:kind)
        runner_events = run.events.where("data->>'source' = ?", "workspace")
        assert_equal [ 1, 2, 3, 4 ], runner_events.map { |event| event.data.fetch("sequence") }
        assert_empty provider.requests
      end
    end
    assert_equal 1, starts.size
    assert_equal task, starts.first.fetch(:task)
    assert_match(/zoe-/, starts.first.fetch(:request_id))
    assert_equal [ { run_id: "runner-1", after: 1 } ], polls
    assert client.stopped?
  end

  test "discovers Codex projects and sends the selected backend and project to the runner" do
    @chat.user.update!(admin: true)
    @profile.update!(config: { workspace_backend: "codex" })
    connect_workspace_runner
    starts = []
    client = stub_runner_client(
      list_projects: StubTool.new(->(**) { { projects: %w[zoe-ai tools], truncated: false } }),
      start_task: StubTool.new(lambda do |**arguments|
        starts << arguments
        runner_content("completed", [], result: "Project found")
      end),
      get_task: StubTool.new(->(**) { flunk "A completed task should not be polled" })
    )

    RubyLLM::MCP::Client.stub(:new, client) do
      assert_no_difference -> { @chat.agent_runs.count } do
        discovery = delegate(agent: @profile.name, task: "Find the project")
        assert_equal %w[zoe-ai tools], discovery.fetch("projects")
        assert discovery.fetch("needs_project")
      end
      reply = delegate(agent: @profile.name, task: "Inspect the project", project: "zoe-ai")
      assert_equal "completed", reply.fetch("status")
    end
    assert_equal [{ backend: "codex", project: "zoe-ai" }], starts.map { |arguments| arguments.slice(:backend, :project) }
  end

  test "agent JSON settings allow backend-specific options and require an object" do
    @profile.update!(config_json: '{"workspace_backend":"codex","options":{"example":true}}')
    assert_equal "codex", @profile.reload.workspace_backend
    assert_equal({ "example" => true }, @profile.config.fetch("options"))

    assert_not @profile.update(config_json: '["codex"]')
    assert @profile.errors.of_kind?(:config_json, :invalid_json)
  end

  test "propagates a terminal runner failure without calling the model" do
    @chat.user.update!(admin: true)
    connect_workspace_runner
    client = stub_runner_client(
      start_task: StubTool.new(->(**) { runner_content("failed", [], error: "Permission denied in workspace") }),
      get_task: StubTool.new(->(**) { flunk "A terminal workspace task should not be polled" })
    )
    with_provider do |provider|
      RubyLLM::MCP::Client.stub(:new, client) do
        detail = delegate(task: "Open a private file", agent: @profile.name)
        assert_equal "failed", detail.fetch("status")
        assert_equal "Permission denied in workspace", detail.fetch("error")
        assert_equal "failed", AgentRun.find(detail.fetch("run_id")).workspace_status
      end
      assert_empty provider.requests
    end
    assert client.stopped?
  end

  test "reports denied runner access without forwarding the transport diagnostic" do
    @chat.user.update!(admin: true)
    connect_workspace_runner
    errors = RubyLLM::MCP::Errors
    client = stub_runner_client

    [
      errors::AuthenticationRequiredError.new(message: "internal authentication detail"),
      errors::TransportError.new(code: 403, message: "internal authorization detail")
    ].each do |error|
      client.stub(:start, -> { raise error }) do
        RubyLLM::MCP::Client.stub(:new, client) do
          detail = delegate(task: "List projects", agent: @profile.name)
          assert_equal "failed", detail.fetch("status")
          assert_match(/runner rejected access/, detail.fetch("error"))
          refute_includes detail.fetch("error"), error.message
        end
      end
    end
  end

  test "adopts a migrated runner dialog without sending the follow-up to a different runner" do
    @chat.user.update!(admin: true)
    connect_workspace_runner
    conversation = create_conversation(local_workspace: true)
    original = create_turn(conversation, task: "Read README.md")
    original.update!(workspace_run_id: "original-run", workspace_status: "completed", workspace_sequence: 5)
    original.finish!(result: "It describes a Rails app.")
    arguments = { task: "What framework did you see?", conversation_id: conversation.id }
    calls = []
    client = stub_runner_client(
      start_task: StubTool.new(lambda do |**options|
        calls << [:start, options]
        runner_content("completed", [], run_id: "next-run", result: "Rails", conversation_id: "same-dialog")
      end),
      get_task: StubTool.new(lambda do |**options|
        calls << [:get, options]
        runner_content("completed", [], run_id: "original-run", conversation_id: "same-dialog")
      end)
    )

    RubyLLM::MCP::Client.stub(:new, client) do
      detail = delegate(**arguments)
      assert_equal "completed", detail.fetch("status")
      assert_equal "Rails", detail.fetch("result")
      assert_equal conversation.id, detail.fetch("conversation_id")
      assert_predicate AgentRun.find(detail.fetch("run_id")), :local_workspace?
    end
    assert_equal [:get, { run_id: "original-run", after: 5 }], calls.first
    assert_equal :start, calls.last.first
    assert_equal "same-dialog", calls.last.last.fetch(:conversation_id)
    assert_equal arguments.fetch(:task), calls.last.last.fetch(:task)
    assert_equal "runner-instance", conversation.reload.workspace_runner_id

    other_runner = stub_runner_client(
      start_task: StubTool.new(->(**) { flunk "The follow-up must not be sent to a different runner" }),
      get_task: StubTool.new(lambda do |**|
        runner_content("completed", [], run_id: "next-run", runner_id: "other-instance", conversation_id: "same-dialog")
      end)
    )
    RubyLLM::MCP::Client.stub(:new, other_runner) do
      failed = delegate(**arguments)
      assert_equal "failed", failed.fetch("status")
      assert_match(/different local workspace runner/, failed.fetch("error"))
    end

    @chat.user.update!(admin: false)
    assert_match(/unavailable/, tool.call(arguments).fetch(:error))
  end

  private

  def queue_adapter_for_test
    ActiveJob::QueueAdapters::TestAdapter.new
  end

  def tool(chat = @chat)
    AI::Tools::DelegateTask.new(chat)
  end

  def delegate(chat: @chat, **arguments)
    AI::AgentRunProgress.stub(:broadcast, nil) { JSON.parse(tool(chat).call(arguments)) }
  end

  def matching_chat(user: @chat.user, character: @chat.character, partner: @chat.partner)
    Chat.create!(user:, character:, partner:)
  end

  def create_conversation(agent: @profile, local_workspace: false)
    AgentConversation.create!(
      user: @chat.user, character: @chat.character, partner: @chat.partner, agent:, agent_name: agent.name, local_workspace:
    )
  end

  def create_turn(conversation, task:)
    conversation.runs.create!(
      chat: @chat, agent: conversation.agent, agent_name: conversation.agent_name, local_workspace: conversation.local_workspace?, task:
    )
  end

  def with_provider(*responses)
    provider = StubProvider.new(responses)
    RubyLLM::Models.stub(:resolve, [ StubModel.new("test-model"), provider ]) do
      yield provider
    end
  end

  def assistant_message(content)
    RubyLLM::Message.new(role: :assistant, content:)
  end

  def connect_workspace_runner(active: true)
    server = MCPServer.find_or_initialize_by(key: MCPServer::WORKSPACE_RUNNER_KEY)
    server.update!(name: "Workspace Runner", active:, transport_type: "streamable_http",
                   config: { url: "http://127.0.0.1:7331/mcp" })
    @profile.mcp_servers << server unless @profile.mcp_servers.exists?(server.id)
  end

  def stub_runner_client(**tools)
    Object.new.tap do |client|
      client.define_singleton_method(:start) {}
      client.define_singleton_method(:tool) { |name| tools[name.to_sym] }
      client.define_singleton_method(:stop) { @stopped = true }
      client.define_singleton_method(:stopped?) { @stopped }
    end
  end

  def runner_content(status, events, **extra)
    payload = { run_id: "runner-1", runner_id: "runner-instance", conversation_id: "runner-dialog", status:, events:, **extra }
    RubyLLM::MCP::Content.new(text: payload.to_json)
  end

  def runner_event(sequence, type, message, **details)
    { sequence:, type:, message:, details: }
  end
end
