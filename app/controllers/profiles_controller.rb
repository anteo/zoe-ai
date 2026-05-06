class ProfilesController < ApplicationController
  def show
    @user = current_user
    render_modal
  end

  def update
    @user = current_user
    attrs = profile_params

    unless @user.update(attrs)
      render :show, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(
      :avatar, :first_name, :last_name, :email, :password, :password_confirmation,
      avatar_attachment_attributes: [ :id, :_destroy ]
    )
          .tap do |attrs|
            if attrs[:password].blank?
              attrs.delete(:password)
              attrs.delete(:password_confirmation)
            end
          end
  end
end
