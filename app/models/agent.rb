class Agent < ApplicationRecord
  include ActsAsAgent

  THINKING_EFFORTS = %w[low medium high].freeze

  belongs_to :model, optional: true
  has_and_belongs_to_many :mcp_servers, join_table: :agents_mcp_servers

  validates :name, presence: true
  validates :key, presence: true, if: :builtin?
  validates :key, uniqueness: true, allow_nil: true
  validates :thinking_effort, inclusion: { in: THINKING_EFFORTS }, allow_blank: true
  validate :active_must_remain_enabled, on: :update
  validate :key_must_not_change, on: :update
  before_validation :normalize_blank_key
  before_destroy :prevent_builtin_destroy

  scope :active,   -> { where(active: true) }
  scope :builtin,  -> { where(builtin: true) }
  scope :custom,   -> { where(builtin: false) }

  def self.ransackable_associations(_auth_object = nil)
    %w[model mcp_servers]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[active builtin created_at key name thinking_effort]
  end

  def dom_id
    ActionView::RecordIdentifier.dom_id(self)
  end

  private

  def normalize_blank_key
    self.key = key.presence
  end

  def key_must_not_change
    return unless builtin?
    return unless will_save_change_to_key?

    errors.add(:key, :readonly)
  end

  def active_must_remain_enabled
    return unless builtin?
    return unless will_save_change_to_active?
    return if active?

    errors.add(:active, :readonly)
  end

  def prevent_builtin_destroy
    return unless builtin?

    errors.add(:base, :restrict_destroy)
    throw(:abort)
  end
end
