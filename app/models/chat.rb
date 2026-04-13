class Chat < ApplicationRecord
  acts_as_chat

  belongs_to :user, class_name: "Character"
  belongs_to :partner, class_name: "Character"

  has_many :facts, dependent: :delete_all

  scope :by_character, ->(character) {
    where(user: character).or(where(partner: character))
  }

  attr_reader :message

  def attachments_to_persist
    @attachments_to_persist ||= []
  end

  def other_known_characters
    Character.where.not(id: [ partner, user ])
  end

  def partner_instructions
    partner.instructions.join("\n\n")
  end

  def messages_association
    messages.preload(:attachments_blobs, :tool_calls, :model)
  end

  private

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
    content_text = content_text&.gsub(/\n*\(files attached: \[.*?\]\)/m, "")&.rstrip
    # Force attachments so persist_content is always called
    [ content_text, attachments || [], content_raw ]
  end
end
