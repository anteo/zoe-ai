require "test_helper"

class ChatToolHistoryTest < ActiveSupport::TestCase
  fixtures :characters, :users, :chats

  test "keeps valid tool results and skips orphaned results when replaying chat history" do
    chat = chats(:anton_with_zoe)
    assistant = chat.messages.create!(role: "assistant", content: "")
    call = assistant.tool_calls.create!(tool_call_id: "agent-call", name: "delegate_task", arguments: {})
    result = chat.messages.create!(role: "tool", content: "Agent reply", parent_tool_call: call)
    orphan = chat.messages.create!(role: "tool", content: "Result of a cancelled reply")
    following_user = chat.messages.create!(role: "user", content: "Continue")

    history = chat.send(:order_messages_for_llm, chat.messages_association.to_a)

    assert_equal [assistant.id, result.id, following_user.id], history.map(&:id)
    assert_equal "agent-call", result.to_llm.tool_call_id
    assert Message.exists?(orphan.id)
  end

  test "replays a delegated tool result before a user message sent during the call" do
    chat = chats(:anton_with_zoe)
    assistant = chat.messages.create!(role: "assistant", content: "")
    call = assistant.tool_calls.create!(tool_call_id: "background-call", name: "delegate_task", arguments: {})
    user = chat.messages.create!(role: "user", content: "In the meantime, answer this.")
    result = chat.messages.create!(role: "tool", content: '{"status":"queued"}', parent_tool_call: call)

    history = chat.send(:order_messages_for_llm, chat.messages_association.order(:id).to_a)

    assert_equal [ assistant.id, result.id, user.id ], history.map(&:id)
  end
end
