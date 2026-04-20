# frozen_string_literal: true

class ProfilesController < ApplicationController
  def show
    @user = current_user
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user

    if @user.update(profile_params)
      redirect_to profile_path, notice: t(:text_profile_updated)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation)
          .tap do |attrs|
            if attrs[:password].blank?
              attrs.delete(:password)
              attrs.delete(:password_confirmation)
            elsif attrs[:password_confirmation].blank?
              attrs.delete(:password_confirmation)
            end
          end
  end
end
