class Character < ApplicationRecord
  has_and_belongs_to_many :users

  has_one_attached :avatar
  has_many_attached :images
  accepts_nested_attributes_for :avatar_attachment, allow_destroy: true

  has_many :facts, dependent: :destroy
  has_many :fact_aggregates, dependent: :delete_all
  has_many :instructions, dependent: :delete_all
  has_many :chats, class_name: "Chat", foreign_key: :character_id, dependent: :destroy
  has_many :partner_chats, class_name: "Chat", foreign_key: :partner_id, dependent: :destroy

  accepts_nested_attributes_for :instructions,
    allow_destroy: true,
    reject_if: ->(item) { item[:content].blank? }
  accepts_nested_attributes_for :facts,
    allow_destroy: true
  accepts_nested_attributes_for :images_attachments,
    allow_destroy: true

  normalizes :name, with: ->(value) { value.to_s.strip.presence }
  validates :name, presence: true, length: { maximum: 50 }

  scope :third_party, ->(third_party = true) { where(third_party:) }
  scope :human, -> { third_party(false).where(ai: false) }
  scope :ai, -> { third_party(false).where(ai: true) }

  def self.default_ai
    RequestStore[:default_ai] ||= ai.where(is_default: true).first!
  end

  def to_s
    name
  end

  def prompt_role(chat)
    return "you" if self == chat.partner
    return "interlocutor" if self == chat.character

    "other"
  end

  def prompt_relation(partner:)
    familiar?(partner:) ? "familiar" : "unfamiliar"
  end

  def prompt_type
    return "ai" if ai?
    return "third_party" if third_party?

    "human"
  end

  def last_conversation_time(partner: nil, except: nil)
    scope = chats
    scope = scope.where(partner:) if partner
    scope = scope.where.not(id: except) if except
    last = scope.order(:created_at).last
    return unless last
    last.messages.maximum(:created_at)
  end

  def facts_to_consider(partner: nil)
    scoped = facts
    scoped = scoped.where(partner:) if partner
    ai? ? scoped.excluding_kind("belief") : scoped
  end

  def familiar?(partner:)
    fact_aggregates.where(partner:).bands.exists?
  end
end
