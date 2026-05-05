module Characters
  class IndexComponent < ApplicationComponent
    attr_reader :user

    def initialize(user:)
      @user = user
    end

    def characters
      user.characters.order(:name)
    end

    def human_characters
      characters.human
    end

    def ai_characters
      characters.ai
    end

    def other_characters
      characters.third_party
    end
  end
end
