class MCPServer < ApplicationRecord
  TRANSPORT_TYPES = %w[stdio sse streamable_http streamable http].freeze

  has_and_belongs_to_many :agents, join_table: :agents_mcp_servers

  validates :key, presence: true, uniqueness: true
  validates :transport_type, inclusion: { in: TRANSPORT_TYPES }

  scope :active, -> { where(active: true) }

  after_create  :start_mcp_client
  after_update  :restart_mcp_client, if: :needs_restart?
  after_destroy :stop_mcp_client

  def start!
    start_mcp_client
  end

  def mcp_client
    RubyLLM::MCP.clients[key]
  end

  def mcp_tools
    start! unless mcp_client
    mcp_client&.tools || []
  rescue StandardError => e
    record_error(e)
    []
  end

  def to_mcp_config
    # Top-level keys must be symbols (matched to transport keyword args).
    # env must keep string keys — Open3.popen3 requires them.
    cfg = config.symbolize_keys
    cfg[:env] = cfg[:env]&.stringify_keys
    { name: key, transport_type: transport_type.to_sym, config: cfg }
  end

  private

  def needs_restart?
    saved_change_to_config? || saved_change_to_transport_type? ||
      (saved_change_to_active? && active?)
  end

  def start_mcp_client
    return unless active?

    RubyLLM::MCP.add_client(to_mcp_config)
    mcp_client&.start
    update_column(:last_error, nil)
  rescue StandardError => e
    record_error(e)
  end

  def stop_mcp_client
    RubyLLM::MCP.remove_client(key)
  end

  def restart_mcp_client
    stop_mcp_client
    start_mcp_client
  end

  def record_error(error)
    msg = "#{error.class}: #{error.message}"
    Rails.logger.error("[MCP] #{key}: #{msg}")
    update_column(:last_error, msg)
  end
end
