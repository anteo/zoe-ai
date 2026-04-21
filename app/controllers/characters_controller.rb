# frozen_string_literal: true

class CharactersController < ApplicationController
  def select
    character_id = params[:character_id]
    character = current_user.characters.ai.find_by(id: character_id)
    session[:ai_character_id] = character&.id || Character.default_ai.id
    redirect_to root_path
  end
end
