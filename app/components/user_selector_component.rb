# frozen_string_literal: true

class UserSelectorComponent < ApplicationComponent
  attr_reader :current_user

  def user_options
    @user_options ||= Character.human.order(:name).pluck(:name, :id)
  end

  def initialize(current_user:)
    @current_user = current_user
  end
end