module AI
  module Agents
    class Zoe < BaseAgent
      agent_key :zoe
      chat_model ::Chat
      tools do
        items = [
          Tools::EventSearch,
          Tools::Draw,
          Tools::ManagePostponedMessages,
          Tools::AddCharacterImage,
          Tools::SetCharacterAvatar,
          Tools::ManageOwnInstructions,
          Tools::GetChatHistory
        ]

        items << Tools::FakeTool if Rails.env.development?
        items
      end
      instructions
    end
  end
end
