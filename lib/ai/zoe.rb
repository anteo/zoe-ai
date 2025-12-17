module AI
  class Zoe < BaseAgent
    chat_model ::Chat
    inputs :additional_instructions
    tools [Tools::Draw]
    instructions
  end
end
