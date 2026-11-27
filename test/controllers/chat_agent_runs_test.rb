require "test_helper"

class ChatAgentRunsTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  fixtures :characters, :characters_users, :chats, :users

  setup do
    @chat = chats(:anton_with_zoe)
    @conversation = AgentConversation.create!(user: @chat.user, character: @chat.character, partner: @chat.partner,
                                               agent_name: "Workspace assistant")
    @message = @chat.messages.create!(role: "user", content: "Review the project")
    @run = @chat.agent_runs.create!(agent_conversation: @conversation, trigger_message: @message,
                                    agent_name: @conversation.agent_name, task: "Review the project")
    @frame_id = "agent-runs-#{@chat.id}-#{@message.id}"
    @run_id = "agent-run-#{@run.id}"
    sign_in users(:anton)
  end

  test "shows latest delegated activity and tool arguments under the triggering message" do
    task = "Review the project.\n#{'Check each directory. ' * 20}Include the final summary."
    @run.update!(task:)
    @run.append_event!("status", data: { status: "running" })
    @run.record_workspace_update!(
      workspace_run_id: "workspace-run",
      workspace_status: "running",
      workspace_events: [
        { "sequence" => 1, "type" => "status", "details" => { "status" => "queued" } },
        { "sequence" => 2, "type" => "tool_call", "details" => {
          "tool" => "run_command", "tool_call_id" => "call-1", "arguments" => { "project" => "app", "command" => "git status" }
        } }
      ]
    )

    get chat_path(@chat), headers: { "Accept-Language" => "en" }

    assert_response :success
    assert_select "#message-#{@message.id} turbo-frame##{@frame_id} details##{@run_id} summary" do
      assert_select "[role=status] > span", text: "Calling run_command"
      assert_select "span", text: "Dialog ##{@conversation.id}", count: 0
    end
    assert_select "details##{@run_id} > summary a.btn[href='#{agent_conversation_chat_path(@chat, @conversation)}'][data-turbo-frame='agent-conversation-detail']"
    assert_select ".drawer-end turbo-frame#agent-conversation-detail"
    assert_select ".drawer-content a[data-turbo-frame^='agent-conversation']", count: 0
    assert_select "details##{@run_id} > div > p", text: /Include the final summary\./
    assert_select "details##{@run_id} > div ol > li", count: 1 do
      assert_select "span", text: "run_command"
      assert_select "span[title='command = git status'] > span", text: "command ="
      assert_select "span[title='command = git status'] > code", text: "git status"
      assert_select "pre", count: 0
      assert_select "span[title='project = app'] > code", text: "app"
    end

    get agent_conversation_chat_path(@chat, @conversation),
      headers: { "Turbo-Frame" => "agent-conversation-detail", "Accept-Language" => "en" }

    assert_response :success
    assert_select "#agent-dialog-run-#{@run.id} ol > li code", text: "git status"
    assert_select "#agent-dialog-run-#{@run.id} .message-placeholder", count: 0
  end

  test "puts multiline tool arguments in a closed disclosure" do
    command = "python3 - <<'PY'\nprint('hello')\nPY"
    @run.append_event!("tool_call", data: { tool: "run_command", arguments: { project: "app", command: } })

    get agent_conversation_chat_path(@chat, @conversation),
      headers: { "Turbo-Frame" => "agent-conversation-detail", "Accept-Language" => "en" }

    assert_response :success
    assert_select "#agent-dialog-run-#{@run.id} ol > li details:not([open])" do
      assert_select "summary" do
        assert_select "code", text: "app"
        assert_select "code", text: "python3 - <<'PY'"
      end
      assert_select "pre code", text: /print\('hello'\)/
    end
  end

  test "groups adjacent successful calls from runs without saved arguments" do
    %w[list_files list_files read_file list_files].each do |tool|
      @run.append_event!("tool_call", data: { tool: })
      @run.append_event!("tool_result", data: { tool:, success: true })
    end
    @run.finish!(result: "Done")

    get agent_conversation_chat_path(@chat, @conversation),
      headers: { "Turbo-Frame" => "agent-conversation-detail", "Accept-Language" => "en" }

    assert_response :success
    assert_select "#agent-dialog-run-#{@run.id} ol > li", count: 3 do |calls|
      assert_select calls.first, "span", text: "×2"
      assert_select calls.last, "span", text: "×2", count: 0
    end
  end

  test "broadcasts a compact turn update and serves the completed public activity in the frame" do
    updates = capture_broadcasts(@chat.to_gid_param) do
      @run.append_event!("tool_call", data: { tool: "read_file", tool_call_id: "call-1", arguments: { path: "missing.md" } })
      @run.append_event!("tool_result", data: { tool: "read_file", tool_call_id: "call-1", success: false })
      @run.append_event!("tool_call", data: { tool: "read_file", tool_call_id: "call-2", arguments: { path: "README.md" } })
      @run.append_event!("tool_result", data: { tool: "read_file", tool_call_id: "call-2", success: true })
      @run.append_event!("assistant", message: "internal agent transcript")
      @run.finish!(result: "completed payload " * 2_000)
    end

    assert_equal 5, updates.size
    updates.each do |update|
      assert_includes update, 'action="reload_agent_runs"'
      assert_includes update, "target=\"#{@frame_id}\""
      assert_includes update, "data-agent-conversation-id=\"#{@conversation.id}\""
      assert_operator update.bytesize, :<, 500
    end

    I18n.with_locale(:ru) do
      get agent_runs_chat_path(@chat, message_id: @message.id),
        headers: { "Turbo-Frame" => @frame_id, "Accept-Language" => "ru" }
    end

    assert_response :success
    assert_select "turbo-frame##{@frame_id} details##{@run_id} summary [role=status]", text: "Завершено"
    assert_select "details##{@run_id} li", count: 2 do |calls|
      assert_select calls.first, "[data-tool-error].text-error[title='Ошибка']", text: /read_file/
      assert_select calls.last, "[data-tool-error]", count: 0
    end
    assert_not_includes response.body, "завершил работу"
    assert_not_includes response.body, "internal agent transcript"
    assert_not_includes response.body, "completed payload"
  end

  test "requires ownership to load a chat's run activity" do
    other_user = User.create!(email: "other-agent-runs@example.com", password: "password123", first_name: "Other", confirmed_at: Time.current)
    sign_out users(:anton)
    sign_in other_user

    get agent_runs_chat_path(@chat, message_id: @message.id)

    assert_response :not_found
  end

  test "keeps messages and cards when resend or delete is attempted during an agent run" do
    later = @chat.messages.create!(role: "assistant", content: "An interim update")
    headers = { "Accept" => "text/vnd.turbo-stream.html", "Accept-Language" => "en" }

    post resend_message_path(@message), params: { message: { tts_enabled: false } }, headers:
    assert_response :success
    assert_includes response.body, "Wait for the agent to finish"
    assert Message.exists?(later.id)

    delete message_path(@message), headers:
    assert_response :success
    assert_includes response.body, "Wait for the agent to finish"
    assert Message.exists?(@message.id)
    assert Message.exists?(later.id)
    assert_not @run.reload.hidden_from_chat?
  end

  test "resend hides old cards and keeps the agent history" do
    @run.finish!(result: "Response before restart")
    later = @chat.messages.create!(role: "user", content: "A follow-up")
    later_run = @chat.agent_runs.create!(agent_conversation: @conversation, trigger_message: later,
                                        agent_name: @conversation.agent_name, task: "A follow-up")
    later_run.finish!(result: "Response to follow-up")

    post resend_message_path(@message), params: { message: { tts_enabled: false } },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_select "details##{@run_id}", count: 0
    assert_not Message.exists?(later.id)
    assert @run.reload.hidden_from_chat?
    assert later_run.reload.hidden_from_chat?
    assert_equal @message.id, @run.trigger_message_id

    get agent_runs_chat_path(@chat, message_id: @message.id), headers: { "Turbo-Frame" => @frame_id }
    assert_response :success
    assert_select "details##{@run_id}", count: 0

    get agent_conversation_chat_path(@chat, @conversation)
    assert_response :success
    assert_select "#agent-dialog-run-#{@run.id} .chat-start .chat-bubble", text: "Response before restart"
    assert_select "#agent-dialog-run-#{later_run.id} .chat-start .chat-bubble", text: "Response to follow-up"
  end

  test "deleting a message does not turn its agent card into an unanchored card" do
    @run.finish!(result: "Saved agent history")

    delete message_path(@message), headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_not Message.exists?(@message.id)
    assert_nil @run.reload.trigger_message_id
    assert @run.hidden_from_chat?
    assert_select "details##{@run_id}", count: 0
  end

  test "opens the same dialog across chats for the current identity and renders public turns" do
    @run.append_event!("system", message: "hidden setup instructions")
    @run.append_event!("assistant", message: "hidden internal response")
    @run.finish!(result: "First answer <script>alert('unsafe')</script>")
    later_chat = @chat.user.chats.create!(character: @chat.character, partner: @chat.partner)
    next_turn = later_chat.agent_runs.create!(agent_conversation: @conversation, agent_name: @conversation.agent_name,
                                              task: "Explain your finding")
    next_turn.finish!(result: "The next answer")

    path = agent_conversation_chat_path(later_chat, @conversation)
    get path

    assert_response :success
    assert_select "h1", text: "Workspace assistant"
    assert_select "#agent-conversation-turns > li", count: 2 do |turns|
      assert_includes turns.first.text, "Review the project"
      assert_includes turns.first.text, "First answer <script>alert('unsafe')</script>"
      assert_includes turns.last.text, "Explain your finding"
      assert_includes turns.last.text, "The next answer"
    end
    assert_select ".chat-end .chat-header .font-medium", text: @chat.partner.name, count: 2
    assert_select ".chat-start .chat-header .font-medium", text: @conversation.agent_name, count: 2
    assert_select ".chat-end .chat-bubble", text: /Review the project/
    assert_select ".chat-start .chat-bubble", text: /The next answer/
    assert_select "ol li script", count: 0
    assert_not_includes response.body, "hidden setup instructions"
    assert_not_includes response.body, "hidden internal response"

    get path, headers: { "Turbo-Frame" => "agent-conversation-detail" }

    assert_response :success
    assert_select "turbo-frame#agent-conversation-detail section > header", count: 0
    assert_select "turbo-frame#agent-conversation-detail #agent-conversation-turns > li", count: 2
  end

  test "requires the original identity and admin access for local dialogs" do
    other_character = Character.create!(name: "Another identity")
    other_dialog = AgentConversation.create!(user: @chat.user, character: other_character, partner: @chat.partner,
                                             agent_name: @conversation.agent_name)

    get agent_conversation_chat_path(@chat, other_dialog)

    assert_response :not_found

    @conversation.update!(local_workspace: true)
    @run.update!(local_workspace: true)
    @chat.user.update!(admin: false)

    get agent_conversation_chat_path(@chat, @conversation)

    assert_response :not_found

    get chat_path(@chat)

    assert_response :success
    assert_select "details##{@run_id} a[href='#{agent_conversation_chat_path(@chat, @conversation)}']", count: 0
  end
end
