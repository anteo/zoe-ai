class Agent < ApplicationRecord
  include ActsAsAgent

  belongs_to :model, optional: true
  has_and_belongs_to_many :mcp_servers, join_table: :agents_mcp_servers

  validates :key, presence: true, uniqueness: true
  validates :thinking_effort, inclusion: { in: %w[low medium high] }, allow_nil: true

  scope :active,   -> { where(active: true) }
  scope :builtin,  -> { where(builtin: true) }
  scope :custom,   -> { where(builtin: false) }
end
