class PendingMessage < ApplicationRecord
  belongs_to :author, class_name: "Character"
  belongs_to :recipient, class_name: "Character", foreign_key: :character_id
  belongs_to :partner, class_name: "Character"
  belongs_to :source_message, class_name: "Message", optional: true
  belongs_to :user

  has_many_attached :attachments

  normalizes :content, with: ->(value) { value.to_s.strip }

  after_create_commit :enqueue_immediate_delivery_check

  validates :author, presence: true
  validates :partner, presence: true
  validates :content, length: { maximum: 10_000 }
  validates :user, presence: true
  validate :content_or_attachments_present

  scope :for_delivery, ->(user:, recipient:, partner:) {
    where(user:, recipient:, partner:).order(:created_at, :id)
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

  def postponed?
    true
  end

  def user?
    false
  end

  def deliver_to!(chat)
    message = chat.messages.create!(
      role: :assistant,
      content:,
      initiator: author,
      postponed: true,
      created_at:,
      updated_at: created_at
    )
    message.attachments.attach(attachments.blobs) if attachments.attached?
    message
  end

  private

  def enqueue_immediate_delivery_check
    DeliverPendingMessageJob.perform_later(id)
  end

  def content_or_attachments_present
    return if content.present? || attachments.attached?

    errors.add(:base, "Pending message must have content or attachments")
  end
end
