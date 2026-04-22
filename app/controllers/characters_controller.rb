# frozen_string_literal: true

class CharactersController < ApplicationController
  before_action :find_character, only: [ :edit, :update ]

  def new
    @character = Character.new
    render layout: false if turbo_frame_request?
  end

  def create
    @character = Character.new(character_create_params)
    @character.ai = true

    if @character.save
      current_user.characters << @character
      session[:ai_character_id] = @character.id
      redirect_back fallback_location: root_path, status: :see_other
    else
      render :new, status: :unprocessable_entity, layout: !turbo_frame_request?
    end
  end

  def edit
    render layout: false if turbo_frame_request?
  end

  def update
    if @character.update(character_update_params)
      redirect_back fallback_location: root_path, status: :see_other
    else
      render :edit, status: :unprocessable_entity, layout: !turbo_frame_request?
    end
  end

  def select
    character_id = params[:id]
    character = current_user.characters.ai.find_by(id: character_id)
    session[:ai_character_id] = character&.id || Character.default_ai.id
    redirect_to root_path
  end

  private

  def find_character
    @character = current_user.characters.find_by(id: params[:id])
    head(:not_found) unless @character
  end

  def character_create_params
    params.require(:character).permit(:name, :avatar, instructions_attributes: [ :id, :content, :_destroy ])
  end

  def character_update_params
    params.require(:character).permit(:avatar, instructions_attributes: [ :id, :content, :_destroy ])
  end
end
