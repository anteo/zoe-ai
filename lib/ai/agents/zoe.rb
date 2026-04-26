module AI
  module Agents
    class Zoe < BaseAgent
      chat_model ::Chat
      model ENV["ZOE_MODEL"]
      tools do
        [ Tools::EventSearch, Tools::Draw, Tools::AddCharacterImage, Tools::SetCharacterAvatar, *AI.mcp_tools ]
      end
      instructions
    end
  end
end
