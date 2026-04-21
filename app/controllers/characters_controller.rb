# frozen_string_literal: true

class CharactersController < ApplicationController
  def new
    @character = Character.new
    render layout: false if turbo_frame_request?
  end

  def create
    @character = Character.new(character_params)
    @character.ai = true

    if @character.save
      current_user.characters << @character
      session[:ai_character_id] = @character.id
      redirect_to root_path
    else
      render :new, status: :unprocessable_entity, layout: !turbo_frame_request?
    end
  end

  def select
    character_id = params[:character_id]
    character = current_user.characters.ai.find_by(id: character_id)
    session[:ai_character_id] = character&.id || Character.default_ai.id
    redirect_to root_path
  end

  private

  def character_params
    params.require(:character).permit(:name, :avatar, instructions_attributes: [:content])
  end
end
