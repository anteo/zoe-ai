class User < ApplicationRecord
  has_and_belongs_to_many :characters
  belongs_to :main_character, class_name: "Character", optional: true
  has_many :chats, dependent: :destroy

  def gravatar_url(size: 128)
    return nil unless email.present?

    hash = Digest::SHA256.hexdigest(email.strip.downcase)
    "https://0.gravatar.com/avatar/#{hash}?s=#{size}&d=initials&name=#{CGI.escape(full_name)}"
  end

  def initials
    [first_name[0], last_name[0]].compact.join.upcase
  end

  def full_name
    [ first_name, last_name ].compact_blank.join(" ")
  end
end
