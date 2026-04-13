class User < ApplicationRecord
  has_one :character

  def gravatar_url(size: 32)
    return nil unless email.present?

    hash = Digest::SHA256.hexdigest(email.strip.downcase)
    "https://0.gravatar.com/avatar/#{hash}?s=#{size}&d=initials&name=#{CGI.escape(full_name)}"
  end

  def full_name
    [ first_name, last_name ].compact_blank.join(" ")
  end
end
