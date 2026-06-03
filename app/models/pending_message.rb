class PendingMessage < ApplicationRecord
  belongs_to :author, class_name: "Character"
  belongs_to :character
  belongs_to :source_message, class_name: "Message", optional: true

  has_many_attached :attachments

  normalizes :content, with: ->(value) { value.to_s.strip }

  validates :author, presence: true
  validates :content, length: { maximum: 10_000 }
  validate :content_or_attachments_present

  scope :for_delivery, ->(character:, author:) {
    where(character:, author:).order(:created_at, :id)
  }

  def assistant?
    true
  end

  def error?
    false
  end

  def memorize
    true
  end

  def user?
    false
  end

  def deliver_to!(chat)
    message = chat.messages.create!(
      role: :assistant,
      content:,
      created_at:,
      updated_at: created_at
    )
    message.attachments.attach(attachments.blobs) if attachments.attached?
    message
  end

  private

  def content_or_attachments_present
    return if content.present? || attachments.attached?

    errors.add(:base, "Pending message must have content or attachments")
  end
end
