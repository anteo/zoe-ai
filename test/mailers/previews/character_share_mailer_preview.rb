class CharacterShareMailerPreview < ApplicationMailerPreview
  def share_link
    character = sample_character
    sender = character.author || sample_user
    recipient_email = "friend@example.com"

    CharacterShareMailer.with(
      character:,
      recipient_email:,
      sender:,
      share_url: accept_share_characters_url(
        token: character.signed_id(purpose: "character_share:#{recipient_email}", expires_in: 14.days),
        email: recipient_email
      )
    ).share_link
  end
end
