class Chat < ApplicationRecord
  acts_as_chat

  belongs_to :user
  belongs_to :character, class_name: "Character"
  belongs_to :partner, class_name: "Character"
  belongs_to :first_visible_message, class_name: "Message", optional: true
  belongs_to :last_visible_message, class_name: "Message", optional: true

  has_many :facts, dependent: :destroy
  has_many :agent_runs, dependent: :destroy
  has_many :attachments_blobs, through: :messages

  skip_callback :save, :before, :resolve_model_from_strings
  before_save :resolve_model_from_strings_safe

  scope :dreaming, ->(dream = true) { where(dream:) }
  scope :closed, ->(closed = true) { where(closed:) }
  scope :by_character, ->(character) {
    where(character:).or(where(partner: character))
  }
  scope :stale, -> { dreaming(false).closed(false).where("created_at < ?", Date.current) }
  scope :with_summary, -> { where.not(summary: [ nil, "" ]) }

  attr_reader :message
  attr_accessor :agent_run_trigger_message_id, :agent_run_job_owner

  def attachments_to_persist
    @attachments_to_persist ||= []
  end

  def staged_attachment_blobs
    attachments_to_persist.filter_map do |attachment|
      case attachment
      when ActiveStorage::Blob
        attachment
      when ActiveStorage::Attachment, ActiveStorage::Attached::One
        attachment.blob
      when ActiveStorage::Attached::Many
        attachment.blobs
      end
    end.flatten
  end

  def described_character(character, mode: :xml, period_order: :asc)
    @described_characters ||= {}
    key = [ character.id, partner_id, mode.to_s, period_order.to_s ]
    @described_characters[key] ||= AI::Actors::DescribeCharacter.result(character:, partner:, mode:, period_order:).description.to_s
  end

  def described_identities(mode: :xml, period_order: :asc)
    user.characters.order(:id).filter_map do |item|
      next if item == partner || item == character

      description = described_character(item, mode:, period_order:)
      next if description.blank?

      [ item, description ]
    end
  end

  def partner_conversation_instructions
    partner_instructions(dream: false)
  end

  def partner_dream_instructions
    partner_instructions(dream: true)
  end

  def partner_instructions(dream: self.dream?)
    global_instructions = Instruction[:character_id].eq(nil)
    character_instructions = Instruction[:character_id].eq(partner.id)

    Instruction.active
               .where(dream:)
               .where(global_instructions.or(character_instructions))
               .ordered
               .map { "* #{it}" }
               .join("\n")
  end

  def messages_association
    messages.preload(:attachments_blobs, :tool_calls, :parent_tool_call, :model)
  end

  def instructions
    to_llm.messages.detect { it.role == :system }&.content
  end

  def latest_user_message_id
    self.class.uncached do
      messages.where(role: "user").reorder(id: :desc).limit(1).pick(:id)
    end
  end

  def latest_assistant_message_content
    messages
      .visible
      .where(role: :assistant)
      .reorder(created_at: :desc, id: :desc)
      .limit(1)
      .pick(:content)
  end

  def stale_trigger_message?(trigger_message_id)
    latest_user_message_id != trigger_message_id
  end

  def sibling_chats
    user.chats.where(character:, partner:)
  end

  def deliver_pending_messages!
    target_character = dream? ? partner : character

    PendingMessage.transaction do
      pending_messages = PendingMessage.for_delivery(user:, recipient: target_character, partner: partner).lock
      pending_messages.each do |pending_message|
        pending_message.deliver_to!(self)
        pending_message.destroy!
      end
    end

    refresh_history_message_metadata!
  end

  def yesterday_summary
    @yesterday_summary ||= begin
      character.chats
               .closed
               .dreaming(false)
               .created_yesterday
               .with_summary
               .where(partner:)
               .order(:created_at)
               .pluck(:summary)
               .join("\n\n")
    end
  end

  def latest_dream_carryover
    @latest_dream_carryover ||= begin
      return if dream?

      dream_chat = sibling_chats
        .dreaming(true)
        .closed
        .with_summary
        .where("closed_at <= ?", created_at || Time.current)
        .order(closed_at: :desc, created_at: :desc, id: :desc)
        .first
      return unless dream_chat

      intervening_chat_exists = sibling_chats
        .dreaming(false)
        .where.not(id: id)
        .where("created_at > ? AND created_at < ?", dream_chat.closed_at, created_at || Time.current)
        .exists?
      return if intervening_chat_exists

      dream_chat
    end
  end

  def token_usage_total
    token_usage_message&.input_tokens.to_i + token_usage_message&.output_tokens.to_i
  end

  def token_usage_context_window
    resolved_model&.context_window.to_i
  end

  def token_usage_percentage
    return 0 if token_usage_context_window <= 0

    ((token_usage_total.to_f / token_usage_context_window) * 100).round.clamp(0, 100)
  end

  def refresh_history_message_metadata!
    first_message = history_visible_messages.reorder(:created_at, :id).first
    last_message = history_visible_messages.reorder(created_at: :desc, id: :desc).first

    update_columns(
      first_visible_message_id: first_message&.id,
      first_visible_message_at: first_message&.created_at,
      last_visible_message_id: last_message&.id,
      last_visible_message_at: last_message&.created_at
    )
  end

  def to_llm
    resolve_model_from_strings
    raise AI::ModelNotConfiguredError if model.blank?

    super
  end

  def resolved_model
    resolve_model_from_strings
    model
  end

  private

  def resolve_model_from_strings
    AI::ModelRegistry.sync!
    super
  rescue RubyLLM::ConfigurationError
    raise AI::ModelNotConfiguredError
  end

  def resolve_model_from_strings_safe
    resolve_model_from_strings
  rescue AI::ModelNotConfiguredError
    nil
  end

  def history_visible_messages
    messages.history_visible
  end

  def order_messages_for_llm(messages)
    messages = messages.reject do |message|
      message.error? || (message.role == "tool" && message.parent_tool_call&.tool_call_id.blank?)
    end
    system_messages, conversation_messages = messages.partition { |message| message.role.to_s == "system" }
    system_messages + conversation_messages
  end

  def token_usage_message
    messages.where(role: "assistant").where.not(input_tokens: nil).reorder(created_at: :desc).first
  end

  def prepare_for_active_storage(attachments)
    active_storage_attachments, other = attachments.partition { |a| a.is_a?(Hash) && a[:io].present? }
    active_storage_attachments + super(other)
  end

  def persist_content(message_record, attachments)
    if message_record.visible?
      attachments ||= []
      attachments.concat(attachments_to_persist)
      attachments_to_persist.clear
    end
    super if attachments.present?
  end

  def prepare_content_for_storage(content)
    content_text, attachments, content_raw = super
    if content_text.is_a?(String) && @message&.assistant?
      @pending_tts_style = Message.extract_tts_style(content_text)
    end
    content_text = Message.humanize_content(content_text) if content_text.is_a?(String)
    # Force attachments so persist_content is always called
    [ content_text, attachments || [], content_raw ]
  end

  def persist_message_completion(message)
    super

    return unless @message&.assistant?

    @message.update_column(:tts_style, @pending_tts_style)

    return if @message.valid_assistant_completion?

    log_empty_assistant_response(message)
    raise AI::EmptyAssistantResponseError
  ensure
    @pending_tts_style = nil
  end

  def log_empty_assistant_response(message)
    raw_response = message&.raw
    response_body = raw_response&.body
    choice = response_body.is_a?(Hash) ? response_body.dig("choices", 0) : nil
    response_message = choice.is_a?(Hash) ? choice["message"] : nil
    response_content = response_message.is_a?(Hash) ? response_message["content"] : nil
    response_thinking = if response_message.is_a?(Hash)
      response_message.values_at("reasoning_content", "reasoning", "thinking").compact.join
    end

    Rails.logger.warn(
      "Empty assistant response: #{JSON.generate(
        chat_id: id,
        provider: resolved_model&.provider,
        configured_model_id: resolved_model&.model_id,
        response_model_id: message&.model_id,
        response_class: raw_response&.class&.name,
        response_status: raw_response&.respond_to?(:status) ? raw_response.status : nil,
        response_body_class: response_body&.class&.name,
        response_body_bytes: response_body.to_json.bytesize,
        response_body_keys: response_body.is_a?(Hash) ? response_body.keys : nil,
        response_error_present: response_body.is_a?(Hash) && response_body["error"].present?,
        choices_count: response_body.is_a?(Hash) ? Array(response_body["choices"]).size : nil,
        finish_reason: choice.is_a?(Hash) ? choice["finish_reason"] : nil,
        response_message_keys: response_message.is_a?(Hash) ? response_message.keys : nil,
        response_content_class: response_content&.class&.name,
        response_content_length: response_content.to_s.length,
        response_thinking_length: response_thinking&.length,
        response_tool_calls_count: response_message.is_a?(Hash) ? Array(response_message["tool_calls"]).size : nil,
        parsed_content_class: message&.content&.class&.name,
        parsed_content_length: message&.content.to_s.length,
        parsed_thinking_length: message&.thinking&.text.to_s.length,
        parsed_tool_calls_count: message&.tool_calls.to_h.size,
        input_tokens: message&.input_tokens,
        output_tokens: message&.output_tokens,
        thinking_tokens: message&.thinking_tokens
      )}"
    )
  rescue => e
    Rails.logger.warn("Failed to log empty assistant response diagnostics: #{e.class}: #{e.message}")
  end
end
