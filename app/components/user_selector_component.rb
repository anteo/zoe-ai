# frozen_string_literal: true

class UserSelectorComponent < ApplicationComponent
  attr_reader :current_user

  def user_options
    @user_options ||= Character.selectable.order(:name)
  end

  def initialize(current_user:)
    @current_user = current_user
  end
end