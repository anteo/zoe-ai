class CharactersController < ApplicationController
  before_action :find_character, only: [ :edit, :update, :destroy, :section, :share, :deliver_share ]
  before_action :require_owned_character!, only: [ :update, :share, :deliver_share ]

  def index
    render_modal
  end

  def new
    @character = Character.new
    render_modal
  end

  def create
    @character = Character.new(character_create_params)
    @character.ai = true
    @character.author = current_user

    if @character.save
      current_user.characters << @character
      session[:partner_id] = @character.id if params[:select_on_save] == "1"
      render action: :update
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    render_modal
  end

  def section
    @section = permitted_section
    render layout: false
  end

  def update
    return head(:forbidden) unless @character.editable_by?(current_user)

    unless update_character!
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    return head(:forbidden) unless @character.detachable_by?(current_user)

    if @character.owned_by?(current_user)
      @character.destroy!
    else
      current_user.characters.destroy(@character)
    end

    if @current_partner == @character
      session[:partner_id] = nil
      render_refresh
    else
      render action: :update
    end
  end

  def select
    character_id = params[:id]
    character = current_user.characters.ai.find_by(id: character_id)
    session[:partner_id] = character&.id || Character.default_ai.id
    render_refresh
  end

  def share
    @character_share_form = CharacterShareForm.new
    render_modal
  end

  def deliver_share
    @character_share_form = CharacterShareForm.new(character_share_params)
    unless @character_share_form.valid?
      return render :share, status: :unprocessable_entity
    end

    recipient_email = @character_share_form.email

    share_url = accept_share_characters_url(
      token: @character.signed_id(purpose: share_purpose(recipient_email), expires_in: 14.days),
      email: recipient_email
    )

    CharacterShareMailer.with(
      character: @character,
      recipient_email:,
      sender: current_user,
      share_url:
    ).share_link.deliver_later

    flash[:notice] = t(:text_character_share_sent, email: recipient_email)
  end

  def accept_share
    recipient_email = normalize_email(params[:email])
    character = Character.find_signed!(params[:token], purpose: share_purpose(recipient_email))

    unless current_user.email == recipient_email
      return redirect_to root_path, alert: t(:text_character_share_wrong_account, email: recipient_email)
    end

    already_shared = current_user.characters.exists?(character.id)
    current_user.characters << character unless already_shared

    redirect_to root_path, notice: t(already_shared ? :text_character_share_already_added : :text_character_share_accepted, character: character.name)
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    redirect_to root_path, alert: t(:text_character_share_invalid)
  end

  private

  def find_character
    @character = current_user.characters.find_by(id: params[:id])
    head(:not_found) unless @character
  end

  def character_create_params
    params.require(:character).permit(
      :bio, :name, :avatar,
      avatar_attachment_attributes: [ :id, :_destroy ],
      instructions_attributes: [ :id, :content, :_destroy ]
    )
  end

  def character_update_params
    params.fetch(:character, {}).permit(
      :bio,
      :avatar,
      avatar_attachment_attributes: [ :id, :_destroy ],
      images: [],
      new_images_descriptions: {},
      facts_attributes: [ :id, :content, :_destroy ],
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
    @character.detachable_by?(current_user)
  end

  def permitted_section
    allowed = %w[memory_profile events facts images]
    allowed << "instructions" if @character.ai?

    params[:section].to_s.in?(allowed) ? params[:section].to_s : allowed.first
  end

  def normalize_email(value)
    value.to_s.strip.downcase
  end

  def character_share_params
    params.fetch(:character_share, {}).permit(:email)
  end

  def require_owned_character!
    head(:forbidden) unless @character&.owned_by?(current_user)
  end

  def share_purpose(email)
    "character_share:#{email}"
  end
end
