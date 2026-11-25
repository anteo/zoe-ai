module ActsAsAgent
  extend ActiveSupport::Concern

  # Returns an in-memory AI::Chat configured from this DB record.
  # Use this for agents whose configuration lives entirely in the database.
  def chat(chat: nil, **kwargs)
    llm_chat = build_agent_chat(model || chat&.model, **kwargs)
    configure_agent_chat(llm_chat, chat:)
    llm_chat
  end

  private

  def build_agent_chat(selected_model, **kwargs)
    AI::ModelRegistry.sync!
    opts = selected_model ? { model: selected_model.model_id, provider: selected_model.provider } : {}
    AI.chat(**opts.merge(kwargs))
  end

  def configure_agent_chat(llm_chat, chat:)
    llm_chat.with_instructions(instructions) if instructions.present?
    llm_chat.with_temperature(temperature) if temperature.present?
    if thinking_effort.present?
      llm_chat.with_thinking(effort: thinking_effort, budget: thinking_budget)
    end
    tools = active_mcp_tools(chat:)
    llm_chat.with_tools(*tools) unless tools.empty?
  end

  def active_mcp_tools(chat: nil)
    tools = mcp_servers.for_agent_tools.flat_map(&:mcp_tools)
    return tools unless chat.present?

    AI.wrap_mcp_tools(chat, tools)
  end
end
