class CharacterShareMailer < ApplicationMailer
  def share_link
    @character = params[:character]
    @recipient_email = params[:recipient_email]
    @sender = params[:sender]
    @share_url = params[:share_url]

    mail(
      to: @recipient_email,
      subject: I18n.t(:text_character_share_subject, sender: @sender.full_name, character: @character.name)
    )
  end
end
