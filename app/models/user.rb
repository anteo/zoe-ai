class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :confirmable, :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

  has_and_belongs_to_many :characters
  belongs_to :main_character, class_name: "Character", optional: true
  has_many :chats, dependent: :destroy
  has_one_attached :avatar
  accepts_nested_attributes_for :avatar_attachment, allow_destroy: true

  normalizes :email, with: ->(value) { value.strip.downcase }
  normalizes :first_name, :last_name, with: ->(value) { value.strip.presence }
  validates :first_name, :email, presence: true

  after_create_commit :ensure_default_characters!
  after_create_commit :promote_to_admin_if_first!

  def gravatar_url(size: 128)
    return nil unless email.present?

    hash = Digest::SHA256.hexdigest(email.strip.downcase)
    "https://0.gravatar.com/avatar/#{hash}?s=#{size}&d=initials&name=#{CGI.escape(full_name)}"
  end

  def initials
    [first_name&.[](0), last_name&.[](0)].compact.join.upcase
  end

  def full_name
    [ first_name, last_name ].compact_blank.join(" ")
  end

  def self.from_omniauth(auth)
    user = find_or_initialize_by(provider: auth.provider, uid: auth.uid)

    if user.new_record? && auth.info.email.present?
      existing_user = find_by(email: auth.info.email)
      user = existing_user if existing_user.present?
    end

    user.provider = auth.provider
    user.uid = auth.uid
    user.email = auth.info.email if auth.info.email.present?
    user.first_name = auth.info.first_name if auth.info.first_name.present?
    user.last_name = auth.info.last_name if auth.info.last_name.present?
    user.first_name ||= auth.info.name.to_s.split.first.presence
    user.first_name ||= auth.info.email.to_s.split("@").first.presence
    user.password = Devise.friendly_token[0, 32] if user.encrypted_password.blank?
    user.confirmed_at ||= Time.current if auth.info.email.present?

    user.save!
    user
  end

  private

  def promote_to_admin_if_first!
    update_column(:admin, true) if User.count == 1
  end

  def ensure_default_characters!
    default_ai = Character.default_ai
    characters << default_ai if default_ai && !characters.exists?(default_ai.id)

    return if characters.human.exists?

    character = Character.create!(name: first_name)

    characters << character
    update_column(:main_character_id, character.id)
  end
end
