class Chat < ApplicationRecord
  acts_as_chat

  belongs_to :user
  belongs_to :character, class_name: "Character"
  belongs_to :partner, class_name: "Character"
  belongs_to :first_visible_message, class_name: "Message", optional: true
  belongs_to :last_visible_message, class_name: "Message", optional: true

  has_many :facts, dependent: :destroy
  has_many :attachments_blobs, through: :messages

  skip_callback :save, :before, :resolve_model_from_strings
  before_save :resolve_model_from_strings_safe

  scope :by_character, ->(character) {
    where(character:).or(where(partner: character))
  }
  scope :stale, -> { where(closed: false).where("created_at < ?", Date.current) }

  attr_reader :message

  def attachments_to_persist
    @attachments_to_persist ||= []
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

  def partner_instructions
    instructions = Instruction.arel_table
    global_instructions = instructions[:character_id].eq(nil)
    character_instructions = instructions[:character_id].eq(partner.id)

    Instruction.active
               .where(global_instructions.or(character_instructions))
               .ordered
               .map { "* #{it}" }
               .join("\n")
  end

  def messages_association
    messages.preload(:attachments_blobs, :tool_calls, :model)
  end

  def latest_user_message_id
    messages.where(role: "user").reorder(id: :desc).limit(1).pick(:id)
  end

  def stale_trigger_message?(trigger_message_id)
    latest_user_message_id != trigger_message_id
  end

  def yesterday_summary
    @yesterday_summary ||= begin
      character.chats
               .where(partner:, closed: true)
               .where(created_at: Date.yesterday.all_day)
               .where.not(summary: [ nil, "" ])
               .order(:created_at)
               .pluck(:summary)
               .join("\n\n")
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
    super(messages.reject(&:error?))
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
    content_text = Message.humanize_content(content_text) if content_text.is_a?(String)
    # Force attachments so persist_content is always called
    [ content_text, attachments || [], content_raw ]
  end

  def persist_message_completion(message)
    super

    return unless @message&.assistant?
    return if @message.valid_assistant_completion?

    raise AI::EmptyAssistantResponseError
  end
end
