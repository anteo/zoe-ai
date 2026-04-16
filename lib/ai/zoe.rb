module AI
  class Zoe < BaseAgent
    chat_model ::Chat
    model ENV["ZOE_MODEL"]
    tools [ Tools::Draw, Tools::AddCharacterImage, Tools::SetCharacterAvatar ]
    instructions
  end
end
