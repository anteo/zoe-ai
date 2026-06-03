module AI
  module Agents
    class Dreaming < BaseAgent
      agent_key :dreaming
      chat_model ::Chat
      tools do
        [
          Tools::EventSearch,
          Tools::Draw,
          Tools::ManagePostponedMessages,
          Tools::ManageOwnInstructions,
          Tools::GetChatHistory
        ]
      end
      instructions
    end
  end
end
