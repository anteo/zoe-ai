class ChatsController < ApplicationController
  before_action :find_chat, only: [ :show ]
  before_action :find_history_chat, only: [ :agent_conversation, :agent_run, :history_detail, :destroy ]
  before_action :find_default_chat, only: [ :show ]
  before_action :build_default_chat, only: [ :new, :show ]
  before_action :load_history_chats, only: [ :history_list, :destroy ]
  before_action :require_admin!, only: [ :destroy ]

  attr_reader :chat
  helper_method :chat

  def new
    render "show"
  end

  def show
  end

  def agent_conversation
    @agent_conversation = AgentConversation.for_chat_identity(@history_chat).find_by(id: params[:conversation_id])
    return head(:not_found) unless @agent_conversation

    runs = @agent_conversation.runs
    runs.reconcile_interrupted!
    @conversation_runs = runs.select(:id, :agent_name, :task, :status, :result, :created_at, :finished_at)
                             .order(:id).preload(:progress_events)
  end

  def agent_run
    runs = @history_chat.agent_runs.where(id: params[:run_id])
    runs.shown_in_chat.reconcile_interrupted!
    run = runs.preload(:progress_events).first
    return head(:not_found) unless run

    if run.hidden_from_chat?
      render html: helpers.turbo_frame_tag(Chats::AgentRunComponent.frame_id(run.id)), layout: false
    else
      render Chats::AgentRunComponent.new(chat: @history_chat, run:), layout: false
    end
  end

  def destroy
    deleted_current_chat = @history_chat.id == params[:current_chat_id].to_i
    @history_chat.destroy

    return render_refresh if deleted_current_chat

    render :history_results
  end

  def history_detail
    render Chats::HistoryDetailComponent.new(history_chat: @history_chat, current_character:)
  end

  def history_list
    render :history_results if turbo_frame_request_id == "history-chat-results"
  end

  private

  def find_chat
    return unless params[:id].present?
    @chat = current_user.chats.dreaming(false).find_by(id: params[:id])
    redirect_to(root_path) unless @chat && @chat.partner == current_partner && !@chat.closed?
  end

  def find_history_chat
    @history_chat = history_chats_scope.find_by(id: params[:id])
    head(:not_found) unless @history_chat
  end

  def history_chats_scope
    current_user.chats.dreaming(false).where(character: current_character, partner: current_partner)
  end

  def load_history_chats
    @history_query = params[:q].to_s.strip
    @history_chats = history_chats_scope
      .yield_self { |scope| filter_history_chats(scope, @history_query) }
      .preload(:last_visible_message)
      .order(created_at: :desc)
  end

  def filter_history_chats(scope, query)
    return scope if query.blank?

    scope.joins(:messages)
         .merge(Message.history_visible)
         .where("messages.content ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
         .distinct
  end
end
