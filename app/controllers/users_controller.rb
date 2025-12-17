# frozen_string_literal: true

class UsersController < ApplicationController
  def select
    session[:user_id] = params[:user_id]
    redirect_to root_path
  end
end
