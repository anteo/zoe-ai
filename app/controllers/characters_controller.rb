# frozen_string_literal: true

class CharactersController < ApplicationController
  def new
    @character = Character.new
    render layout: false if turbo_frame_request?
  end

  def create
    @character = Character.new(character_params)
    @character.ai = true

    if save_character_with_instructions(@character)
      current_user.characters << @character
      session[:ai_character_id] = @character.id
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.redirect(root_path) }
        format.html { redirect_to root_path, status: :see_other }
      end
    else
      render :new, status: :unprocessable_entity, layout: !turbo_frame_request?
    end
  end

  def edit
    @character = current_user.characters.ai.find(params[:id])
    render layout: false if turbo_frame_request?
  end

  def update
    @character = current_user.characters.ai.find(params[:id])

    if save_character_with_instructions(@character)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.redirect(root_path) }
        format.html { redirect_to root_path, status: :see_other }
      end
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

  def save_character_with_instructions(character)
    ActiveRecord::Base.transaction do
      character.assign_attributes(character_params.except(:instructions_attributes))
      character.save!

      character.instructions.delete_all
      instruction_contents.each do |content|
        character.instructions.create!(content:)
      end
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def instruction_contents
    @instruction_contents ||= character_params.fetch(:instructions_attributes, {})
      .values
      .map { it[:content].to_s.strip }
      .filter(&:present?)
  end

  def character_params
    params.require(:character).permit(:name, :avatar, instructions_attributes: [:content])
  end
end
