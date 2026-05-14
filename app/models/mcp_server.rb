class MCPServer < ApplicationRecord
  TRANSPORT_TYPES = %w[stdio sse streamable_http streamable http].freeze

  has_and_belongs_to_many :agents, join_table: :agents_mcp_servers

  validates :key, :name, presence: true
  validates :key, uniqueness: true
  validates :transport_type, inclusion: { in: TRANSPORT_TYPES }
  validate :key_must_not_change, on: :update

  before_validation :parse_config_json
  before_save :reactivate_after_connection_change
  before_save :clear_last_error, if: :sync_job_needed_before_save?
  after_commit :enqueue_sync_job, on: [ :create, :update ], if: :sync_job_needed?
  after_destroy_commit :broadcast_remove_settings_row!

  scope :active, -> { where(active: true) }

  def mcp_client
    RubyLLM::MCP.clients[key]
  end

  def mcp_tools
    start_client! unless mcp_client
    mcp_client&.tools || []
  rescue StandardError => e
    record_error!(e)
    []
  end

  def to_mcp_config
    cfg = config.symbolize_keys
    cfg[:env] = cfg[:env]&.stringify_keys
    {
      name: key,
      transport_type: transport_type.to_sym,
      config: cfg
    }
  end

  def config_json
    @config_json ||= config.present? ? JSON.pretty_generate(config) : "{}"
  end

  def config_json=(value)
    @config_json = value
  end

  def job_started?
    @job_started
  end

  def mark_job_started!
    @job_started = true
  end

  def enqueue_destroy_job!
    mark_job_started!
    DestroyMCPServerJob.perform_later(self)
  end

  def dom_id
    ActionView::RecordIdentifier.dom_id(self)
  end

  def broadcast_replace_settings_row!
    Turbo::StreamsChannel.broadcast_component_replace_to(
      MCPServer,
      target: dom_id,
      component: :settings__mcp_server_row,
      mcp_server_row: self
    )
  end

  def broadcast_remove_settings_row!
    Turbo::StreamsChannel.broadcast_remove_to(MCPServer, target: dom_id)
  end

  def sync_client!(rebuild: false)
    if active?
      synchronize_active_client!(rebuild:)
    else
      stop_client!
    end
  rescue StandardError => e
    record_error!(e)
  ensure
    broadcast_replace_settings_row!
  end

  def record_error!(error)
    logger.error("MCP server '#{key}': #{error.message}")
    update_columns last_error: error.message, active: false
  end

  def destroy_with_client_cleanup!
    stop_client!
    destroy!
  rescue StandardError => e
    record_error!(e)
    broadcast_replace_settings_row!
  end

  private

  def parse_config_json
    return if @config_json.blank?

    self.config = JSON.parse(@config_json)
  rescue JSON::ParserError
    errors.add(:config_json, :invalid_json)
    throw(:abort)
  end

  def start_client!
    RubyLLM::MCP.add_client(to_mcp_config)
    mcp_client&.start
  end

  def clear_last_error
    self.last_error = nil
    @job_started = false
  end

  def reactivate_after_connection_change
    return unless persisted? && !active? && last_error.present? &&
                  (will_save_change_to_config? || will_save_change_to_transport_type?)
    
    self.active = true
  end

  def sync_job_needed_before_save?
    new_record? || will_save_change_to_active? || will_save_change_to_config? || will_save_change_to_transport_type?
  end

  def enqueue_sync_job
    mark_job_started!
    SyncMCPServerJob.perform_later(
      self,
      rebuild: previous_changes.slice("config", "transport_type").any?
    )
  end

  def sync_job_needed?
    previous_changes.slice("active", "config", "transport_type").any?
  end

  def synchronize_active_client!(rebuild:)
    if mcp_client
      if rebuild
        rebuild_client!
      else
        mcp_client.restart!
      end
    else
      start_client!
    end
  end

  def rebuild_client!
    stop_client!
    start_client!
  end

  def stop_client!
    RubyLLM::MCP.remove_client(key)
  end

  def key_must_not_change
    errors.add(:key, :readonly) if will_save_change_to_key?
  end
end
