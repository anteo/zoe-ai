class Users::RegistrationsController < Devise::RegistrationsController
  before_action :ensure_self_registration_open!, only: %i[new create]

  private

  def ensure_self_registration_open!
    return if self_registration_open?

    redirect_to new_user_session_path, alert: I18n.t(:text_self_registration_disabled)
  end
end
