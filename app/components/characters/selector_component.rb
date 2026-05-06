module Characters
  class SelectorComponent < ApplicationComponent
    attr_reader :current_partner, :current_user

    def character_options
      @character_options ||= current_user.characters.ai.order(:name)
    end

    def initialize(current_partner:, current_user:)
      @current_partner = current_partner
      @current_user = current_user
    end
  end
end
