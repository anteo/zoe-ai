class DeviseMailerPreview < ApplicationMailerPreview
  def confirmation_instructions
    Devise::Mailer.confirmation_instructions(sample_user, sample_token("confirmation"), {})
  end

  def email_changed
    user = sample_user.dup
    user.email = sample_email
    user.unconfirmed_email = "new-email@example.com"

    Devise::Mailer.email_changed(user, {})
  end

  def email_changed_confirmed
    user = sample_user.dup
    user.email = "confirmed@example.com"
    user.unconfirmed_email = nil

    Devise::Mailer.email_changed(user, {})
  end

  def password_change
    Devise::Mailer.password_change(sample_user, {})
  end

  def reset_password_instructions
    Devise::Mailer.reset_password_instructions(sample_user, sample_token("reset-password"), {})
  end
end
