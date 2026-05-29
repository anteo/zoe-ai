module AI
  module Agents
    class Zoe < BaseAgent
      agent_key :zoe
      chat_model ::Chat
      tools do
        [ Tools::EventSearch, Tools::Draw, Tools::AddCharacterImage, Tools::SetCharacterAvatar, Tools::ManageOwnInstructions ]
      end
      instructions
    end
  end
end
