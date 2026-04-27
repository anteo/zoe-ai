module AI
  module Agents
    class SummarizeChat < BaseAgent
      agent_key :summarize_chat
      inputs :chat
      temperature 0.1
      instructions
    end
  end
end
