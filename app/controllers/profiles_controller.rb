# frozen_string_literal: true

class ProfilesController < ApplicationController
  def show
    @user = current_user
    render layout: false if turbo_frame_request?
  end

  def update
    @user = current_user
    attrs = profile_params

    if @user.update(attrs)
      redirect_after_profile_update
    else
      render :show, status: :unprocessable_entity, layout: !turbo_frame_request?
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

  def redirect_after_profile_update
    if turbo_frame_request?
      redirect_back fallback_location: root_path, notice: t(:text_profile_updated), status: :see_other
    else
      redirect_to profile_path, notice: t(:text_profile_updated)
    end
  end
end
