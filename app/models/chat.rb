class Chat < ApplicationRecord
  acts_as_chat

  belongs_to :user
  belongs_to :character, class_name: "Character"
  belongs_to :partner, class_name: "Character"

  has_many :facts, dependent: :delete_all
  has_many :attachments_blobs, through: :messages

  scope :by_character, ->(character) {
    where(character:).or(where(partner: character))
  }
  scope :stale, -> { where(closed: false).where("created_at < ?", Date.current) }

  attr_reader :message

  def attachments_to_persist
    @attachments_to_persist ||= []
  end

  def other_known_characters
    user.characters.where.not(id: [ partner_id, character_id ])
  end

  def described_character(character, mode: :xml, period_order: :asc)
    @described_characters ||= {}
    key = [ character.id, mode.to_s, period_order.to_s ]
    @described_characters[key] ||= AI::Actors::DescribeCharacter.result(character:, mode:, period_order:).description.to_s
  end

  def known_characters_with_description(mode: :xml, period_order: :asc)
    other_known_characters.filter_map do |item|
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
end
