module AI
  class AgentConversationHistory
    MAX_TURNS = 30
    MAX_HISTORY_BYTES = 96.kilobytes

    def initialize(run)
      @run = run
    end

    def replay_into(llm_chat)
      previous_runs = @run.agent_conversation.runs.where(id: ...@run.id).where.not(status: "running")
                          .order(id: :desc).limit(MAX_TURNS + 1).includes(:events).to_a
      omitted = previous_runs.size > MAX_TURNS
      remaining = history_budget(llm_chat)
      replay = []
      previous_runs.first(MAX_TURNS).each do |previous|
        messages = messages_for(previous)
        cost = messages.to_json.bytesize
        if cost > remaining
          omitted = true
          break if remaining < 256

          messages = excerpt(previous, remaining)
          cost = messages.to_json.bytesize
          break if cost > remaining
        end

        replay << messages
        remaining -= cost
      end
      if omitted
        note = "Some earlier requests or tool observations are omitted from this conversation context."
        llm_chat.with_instructions([ llm_chat.instructions.presence, note ].compact.join("\n\n"))
      end
      replay.reverse_each { |messages| messages.each { |message| llm_chat.add_message(message) } }
    end

    private

    def history_budget(llm_chat)
      window = llm_chat.model.try(:context_window).to_i
      window.positive? ? [window / 2, MAX_HISTORY_BYTES].min : MAX_HISTORY_BYTES
    end

    def messages_for(run)
      messages = [{ role: :user, content: run.task }]
      specialist = specialist_messages(run) if run.completed?
      messages.concat(specialist) if specialist
      messages << { role: :assistant, content: outcome(run) } unless messages.last[:role] == :assistant
      messages
    end

    def excerpt(run, remaining)
      byte_limit = [ (remaining - 160) / 8, 2_048 ].min
      [
        { role: :user, content: "Earlier request excerpt: #{run.task.byteslice(0, byte_limit).scrub("")}" },
        { role: :assistant, content: "Earlier outcome excerpt: #{outcome(run).byteslice(0, byte_limit).scrub("")}" }
      ]
    end

    def outcome(run)
      run.completed? ? run.result.to_s : "The delegated request failed. #{run.error}"
    end

    def specialist_messages(run)
      messages = run.events.select { |event| event.kind.in?(%w[assistant tool_call tool_result]) }
      groups = messages.slice_before { |event| event.kind == "assistant" }
      groups.flat_map do |assistant, *tool_events|
        next [] unless assistant.kind == "assistant"

        results = tool_events.select { |event| event.kind == "tool_result" }.index_by { |event| event.data["tool_call_id"] }
        calls = tool_calls(assistant, tool_events).select { |call| results.key?(call.id) }
        next [] if calls.empty? && assistant.message.blank?

        thinking = if calls.any?
          RubyLLM::Thinking.build(text: assistant.data["thinking"], signature: assistant.data["thinking_signature"])
        end
        assistant_message = {
          role: :assistant, content: assistant.message.to_s, tool_calls: calls.index_by(&:id).presence, thinking:
        }
        tool_messages = calls.map do |call|
          { role: :tool, content: results.fetch(call.id).message.to_s, tool_call_id: call.id }
        end
        [assistant_message, *tool_messages]
      end
    end

    def tool_calls(assistant, tool_events)
      stored = assistant.data["tool_calls"] || tool_events.filter_map do |event|
        next unless event.kind == "tool_call"

        event.data.slice("tool_call_id", "tool", "arguments")
                  .transform_keys("tool_call_id" => "id", "tool" => "name")
      end
      stored.filter_map do |call|
        next unless call["id"].present? && call["name"].present?

        RubyLLM::ToolCall.new(
          id: call.fetch("id"), name: call.fetch("name"), arguments: call.fetch("arguments", {}),
          thought_signature: call["thought_signature"]
        )
      end
    end
  end
end
