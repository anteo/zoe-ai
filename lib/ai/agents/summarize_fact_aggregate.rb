module AI
  module Agents
    class SummarizeFactAggregate < BaseAgent
      agent_key :summarize_fact_aggregate
      inputs :fact_aggregate
      temperature 0.1
      instructions
    end
  end
end
