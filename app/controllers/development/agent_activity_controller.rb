module Development
  class AgentActivityController < ApplicationController
    before_action :build_preview

    def show
      @messages = [
        [ "user", "Запусти тесты Zoe AI и сообщи результат." ],
        [ "user", "И посмотри, что изменилось в раннере." ],
        [ "assistant", "Обе задачи запущены. Я сообщу, когда будут результаты." ],
        [ "user", "Какой сейчас прогресс?" ],
        [ "assistant", "Codex выполняет `bin/rails test`. Workspace Assistant просматривает файлы раннера." ],
        [ "user", "Что вошло в предыдущие изменения?" ],
        [ "assistant", "Во время запроса прогресса отображается индикатор ответа. В `agent_history` теперь видны последние вызовы и их результаты." ],
        [ "user", "Где потом прочитать подробности?" ],
        [ "assistant", "В диалоге агента. Итог также появится в этой ленте." ]
      ].map.with_index { |(role, content), index| preview_message(role, content, index) }
    end

    def dialog
      run = @runs.find { |item| item.agent_conversation_id.to_s == params[:id] }
      return head(:not_found) unless run

      @history_chat = @chat
      @agent_conversation = run.agent_conversation
      @conversation_runs = [ run ]
      render "chats/agent_conversation", locals: { back_path: development_agent_activity_path }
    end

    private

    def build_preview
      @chat = Chat.new(id: 0, user: current_user, character: current_character, partner: current_partner)
      @started_at = Time.current - 5.minutes
      @runs = [
        preview_run(1, "Codex", "Запустить тесты Zoe AI и сообщить результат.\nСначала проверить Rails, затем раннер.",
                    "run_command", { "command" => "bin/rails test" }),
        preview_run(2, "Workspace Assistant", "Посмотреть последние изменения в раннере и кратко описать их.",
                    "list_files", { "path" => "." })
      ]
    end

    def preview_run(id, name, task, tool, arguments)
      conversation = AgentConversation.new(id:, user: current_user, character: current_character, partner: current_partner, agent_name: name)
      run = AgentRun.new(id: -id, chat: @chat, agent_conversation: conversation, agent_name: name, task:,
                         status: "running", workspace_status: "running", created_at: @started_at + id.minutes)
      event = AgentRunEvent.new(id: -id, kind: "tool_call", data: { "tool" => tool, "arguments" => arguments })
      run.association(:progress_events).target = [ event ]
      run
    end

    def preview_message(role, content, index)
      Message.new(id: -(index + 1), chat: @chat, role:, content:, created_at: @started_at + index * 30.seconds,
                  character: role == "user" ? current_character : current_partner, memorize: true)
    end
  end
end
