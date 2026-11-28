module Development
  class AgentActivityController < ApplicationController
    before_action :build_preview, except: :reset

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
      @messages.concat(@runs.select(&:completed?).map { |run| preview_report(run) })
    end

    def run
      run = selected_run
      return head(:not_found) unless run

      render Chats::AgentRunComponent.new(chat: @chat, run:, path_for_conversation: method(:dialog_path)), layout: false
    end

    def finish
      run = selected_run
      return head(:not_found) unless run
      return head(:no_content) unless run.running?

      finished_at = Time.current
      session[:agent_activity_finished] = @finished.merge(params[:id] => finished_at.utc.iso8601(6))
      complete_run(run, finished_at)

      reload = AI::AgentRunProgress.stream_options(run, url: development_agent_activity_run_path(run.agent_conversation_id))
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            helpers.turbo_stream_action_tag(:reload_agent_run, **reload),
            turbo_stream.before(Chats::ChatComponent.placeholder_id(@chat.id), Chats::MessageComponent.new(message: preview_report(run), current_character:)),
            turbo_stream.remove("preview-finish-#{run.agent_conversation_id}")
          ]
        end
        format.html { redirect_to development_agent_activity_path, status: :see_other }
      end
    end

    def reset
      session.delete(:agent_activity_started_at)
      session.delete(:agent_activity_finished)
      redirect_to development_agent_activity_path, status: :see_other
    end

    def dialog
      run = selected_run
      return head(:not_found) unless run

      @history_chat = @chat
      @agent_conversation = run.agent_conversation
      @conversation_runs = [ run ]
      render "chats/agent_conversation", locals: { back_path: development_agent_activity_path }
    end

    private

    def build_preview
      @chat = Chat.new(id: 0, user: current_user, character: current_character, partner: current_partner)
      @started_at = Time.zone.iso8601(session[:agent_activity_started_at] ||= 5.minutes.ago.utc.iso8601(6))
      @finished = session[:agent_activity_finished] || {}
      @runs = [
        preview_run(1, "Codex", "Запустить тесты Zoe AI и сообщить результат.\nСначала проверить Rails, затем раннер.",
                    "run_command", { "command" => "bin/rails test" }),
        preview_run(2, "Workspace Assistant", "Посмотреть последние изменения в раннере и кратко описать их.",
                    "list_files", { "path" => "." })
      ]
      @runs.each do |run|
        finished_at = @finished[run.agent_conversation_id.to_s]
        complete_run(run, Time.zone.iso8601(finished_at)) if finished_at
      end
    end

    def selected_run
      @runs.find { |run| run.agent_conversation_id.to_s == params[:id] }
    end

    def dialog_path(run)
      development_agent_activity_dialog_path(run.agent_conversation_id)
    end

    def complete_run(run, finished_at)
      result = run.agent_conversation_id == 1 ? "Codex завершил тесты без ошибок." : "Workspace Assistant завершил обзор изменений в раннере."
      run.assign_attributes(status: "completed", workspace_status: "completed", finished_at:, result:)
    end

    def preview_report(run)
      preview_message("assistant", run.result, 100 + run.agent_conversation_id, created_at: run.finished_at + Rational(1, 1_000_000))
    end

    def preview_run(id, name, task, tool, arguments)
      conversation = AgentConversation.new(id:, user: current_user, character: current_character, partner: current_partner, agent_name: name)
      run = AgentRun.new(id: -id, chat: @chat, agent_conversation: conversation, agent_name: name, task:,
                         status: "running", workspace_status: "running", created_at: @started_at + id.minutes)
      event = AgentRunEvent.new(id: -id, kind: "tool_call", data: { "tool" => tool, "arguments" => arguments })
      run.association(:progress_events).target = [ event ]
      run
    end

    def preview_message(role, content, index, created_at: @started_at + index * 30.seconds)
      Message.new(id: -(index + 1), chat: @chat, role:, content:, created_at:,
                  character: role == "user" ? current_character : current_partner, memorize: true)
    end
  end
end
