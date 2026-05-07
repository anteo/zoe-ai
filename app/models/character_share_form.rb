class CharacterShareForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Attributes::Normalization

  attribute :email, :string

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  normalizes :email, with: ->(value) { value.to_s.strip.downcase }

  def self.model_name
    ActiveModel::Name.new(self, nil, "CharacterShare")
  end
end
