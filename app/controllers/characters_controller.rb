# frozen_string_literal: true

class CharactersController < ApplicationController
  before_action :find_character, only: [ :edit, :update, :destroy, :section ]

  def index
    load_characters
    render layout: false if turbo_frame_request?
  end

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
      redirect_after_character_create
    else
      render :new, status: :unprocessable_entity, layout: !turbo_frame_request?
    end
  end

  def edit
    render layout: false if turbo_frame_request?
  end

  def section
    @section = permitted_section
    render layout: false
  end

  def update
    if update_character!
      redirect_after_character_save
    else
      render :edit, status: :unprocessable_entity, layout: !turbo_frame_request?
    end
  end

  def destroy
    return redirect_after_character_save unless deletable_character?

    Character.transaction do
      session[:ai_character_id] = nil if session[:ai_character_id].to_s == @character.id.to_s

      if @character.users.where.not(id: current_user.id).exists?
        current_user.characters.destroy(@character)
      else
        @character.destroy!
      end
    end

    redirect_after_character_save
  end

  def select
    character_id = params[:id]
    character = current_user.characters.ai.find_by(id: character_id)
    session[:ai_character_id] = character&.id || Character.default_ai.id
    redirect_to root_path
  end

  private

  def load_characters
    characters = current_user.characters.order(:name)
    @human_characters = characters.human
    @ai_characters = characters.ai
    @other_characters = characters.third_party
  end

  def redirect_after_character_save
    refresh_path = params[:refresh].presence
    if refresh_path
      redirect_to refresh_path, status: :see_other
    else
      redirect_back fallback_location: root_path, status: :see_other
    end
  end

  def redirect_after_character_create
    if turbo_frame_request?
      redirect_to edit_character_path(@character, refresh: params[:refresh]), status: :see_other
    else
      redirect_after_character_save
    end
  end

  def find_character
    @character = current_user.characters.find_by(id: params[:id])
    head(:not_found) unless @character
  end

  def character_create_params
    params.require(:character).permit(:name, :avatar, instructions_attributes: [ :id, :content, :_destroy ])
  end

  def character_update_params
    params.fetch(:character, {}).permit(
      :avatar,
      images: [],
      new_images_descriptions: {},
      instructions_attributes: [ :id, :content, :_destroy ],
      images_attachments_attributes: [ :id, :description, :_destroy ]
    )
  end

  def update_character!
    update_params = character_update_params
    new_images = Array(update_params.delete(:images)).reject(&:blank?)
    new_images_descriptions = normalize_new_image_descriptions(update_params.delete(:new_images_descriptions))

    return false unless @character.update(update_params)

    existing_attachment_ids = @character.images.attachments.pluck(:id)
    @character.images.attach(new_images) if new_images.any?
    apply_new_image_descriptions(existing_attachment_ids:, descriptions: new_images_descriptions)
    true
  end

  def apply_new_image_descriptions(existing_attachment_ids:, descriptions:)
    return if descriptions.empty?

    new_attachments = @character.images.attachments
                              .where.not(id: existing_attachment_ids)
                              .order(:created_at, :id)

    new_attachments.each_with_index do |attachment, index|
      attachment.description = descriptions[index]
      attachment.blob.save! if attachment.blob.changed?
    end
  end

  def normalize_new_image_descriptions(raw_descriptions)
    return [] if raw_descriptions.blank?

    case raw_descriptions
    when ActionController::Parameters
      raw_descriptions.to_h.sort_by { |index, _| index.to_i }.map(&:last)
    when Hash
      raw_descriptions.sort_by { |index, _| index.to_i }.map(&:last)
    when Array
      raw_descriptions
    else
      Array(raw_descriptions)
    end
  end

  def deletable_character?
    !@character.is_default? && current_user.main_character_id != @character.id
  end

  def permitted_section
    allowed = %w[description facts images]
    allowed << "instructions" if @character.ai?

    params[:section].to_s.in?(allowed) ? params[:section].to_s : allowed.first
  end
end
