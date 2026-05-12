class SmtpTestMailer < ApplicationMailer
  def test_email(recipient:)
    @sent_at = Time.current

    mail(
      to: recipient,
      subject: I18n.t(:text_settings_smtp_test_subject)
    )
  end
end
