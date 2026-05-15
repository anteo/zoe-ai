class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    auth = request.env["omniauth.auth"]
    user = existing_omniauth_user(auth)

    if user.blank? && !self_registration_open?
      return redirect_to new_user_session_path, alert: I18n.t(:text_self_registration_disabled)
    end

    user = User.from_omniauth(auth)
    sign_in_and_redirect user, event: :authentication
    set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
  rescue StandardError => e
    Rails.logger.error("Google OAuth callback failed: #{e.class}: #{e.message}")
    redirect_to new_user_session_path, alert: I18n.t(:text_google_sign_in_failed)
  end

  def failure
    redirect_to new_user_session_path, alert: I18n.t(:text_google_sign_in_failed)
  end

  private

  def existing_omniauth_user(auth)
    User.find_by(provider: auth.provider, uid: auth.uid) ||
      auth.info.email.presence && User.find_by(email: auth.info.email)
  end
end
