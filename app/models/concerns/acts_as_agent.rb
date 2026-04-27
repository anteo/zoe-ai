module ActsAsAgent
  extend ActiveSupport::Concern

  # Returns an in-memory AI::Chat configured from this DB record.
  # Use this for agents that live entirely in the database (non-builtin).
  def chat(**kwargs)
    llm_chat = build_agent_chat(**kwargs)
    configure_agent_chat(llm_chat)
    llm_chat
  end

  private

  def build_agent_chat(**kwargs)
    opts = {}
    opts[:model] = model.model_id if model
    AI.chat(**opts.merge(kwargs))
  end

  def configure_agent_chat(llm_chat)
    llm_chat.with_instructions(instructions) if instructions.present?
    llm_chat.with_temperature(temperature) if temperature.present?
    if thinking_effort.present?
      llm_chat.with_thinking(effort: thinking_effort, budget: thinking_budget)
    end
    tools = active_mcp_tools
    llm_chat.with_tools(*tools) unless tools.empty?
  end

  def active_mcp_tools
    mcp_servers.active.flat_map(&:mcp_tools)
  end
end
