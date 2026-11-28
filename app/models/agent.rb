class Agent < ApplicationRecord
  include ActsAsAgent

  THINKING_EFFORTS = %w[low medium high].freeze
  WORKSPACE_BACKENDS = %w[codex].freeze

  self.filter_attributes += [:config]

  belongs_to :model, optional: true
  has_many :agent_runs, dependent: :nullify
  has_and_belongs_to_many :mcp_servers, join_table: :agents_mcp_servers

  validates :name, presence: true
  validates :key, presence: true, if: :builtin?
  validates :key, uniqueness: true, allow_nil: true
  validates :thinking_effort, inclusion: { in: THINKING_EFFORTS }, allow_blank: true
  validate :validate_config
  validate :active_must_remain_enabled, on: :update
  validate :key_must_not_change, on: :update
  before_validation :normalize_blank_key
  before_validation :parse_config_json
  around_save :silence_config_sql, if: :will_save_change_to_config?
  before_destroy :prevent_builtin_destroy

  scope :active,   -> { where(active: true) }
  scope :builtin,  -> { where(builtin: true) }
  scope :custom,   -> { where(builtin: false) }
  scope :delegatable, ->(user) do
    profiles = active.custom
    if user&.admin?
      profiles
    else
      runner_profiles = joins(:mcp_servers).merge(MCPServer.workspace_runner).select(:id)
      profiles.where("agents.config->>'workspace_backend' IS NULL").where.not(id: runner_profiles)
    end
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[model mcp_servers]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[active builtin created_at key name thinking_effort]
  end

  def dom_id
    ActionView::RecordIdentifier.dom_id(self)
  end

  def config_json
    @config_json || JSON.pretty_generate(config)
  end

  attr_writer :config_json

  def workspace_backend
    config["workspace_backend"] if config.is_a?(Hash)
  end

  private

  def parse_config_json
    return unless defined?(@config_json)

    self.config = @config_json.blank? ? {} : JSON.parse(@config_json)
  rescue JSON::ParserError
    errors.add(:config_json, :invalid_json)
  end

  def validate_config
    if !config.is_a?(Hash)
      errors.add(:config_json, :invalid_json)
    elsif !workspace_backend.nil? && !WORKSPACE_BACKENDS.include?(workspace_backend)
      errors.add(:config_json, :unknown_workspace_backend)
    end
  end

  def silence_config_sql(&block)
    ActiveRecord::Base.logger.silence(&block)
  end

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
