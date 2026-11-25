class AgentConversation < ApplicationRecord
  belongs_to :user
  belongs_to :character
  belongs_to :partner, class_name: "Character"
  belongs_to :agent, optional: true

  has_many :runs, class_name: "AgentRun", dependent: :destroy

  scope :for_chat_identity, ->(chat) do
    conversations = where(user_id: chat.user_id, character_id: chat.character_id, partner_id: chat.partner_id)
    chat.user&.admin? ? conversations : conversations.where(local_workspace: false)
  end
end
