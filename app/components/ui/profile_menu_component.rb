module UI
  class ProfileMenuComponent < ApplicationComponent
    attr_reader :current_user

    def initialize(current_user:)
      @current_user = current_user
    end

    def my_character
      current_user.main_character
    end
  end
end
