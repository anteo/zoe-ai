class Message < ApplicationRecord
  acts_as_message

  has_many_attached :attachments
  has_many :facts, dependent: :delete_all

  belongs_to :character, optional: true

  before_save :set_character

  scope :visible, -> { where(role: %w[user assistant]).where.not(content: "") }

  def user?
    role == "user"
  end

  def assistant?
    role == "assistant"
  end

  def visible?
    (user? || assistant?) && content.present?
  end

  def to_direct_speech(**)
    I18n.t(:direct_speech, character:, text: content, **)
  end

  private

  def set_character
    self.character = if user?
      chat.user
    else
      chat.partner
    end
  end

  def extract_content
    if user?
      content = super
      return content unless content.is_a?(RubyLLM::Content)

      with_attachment_ids(content)
    elsif content_raw.present?
      RubyLLM::Content::Raw.new(content_raw)
    else
      with_attachment_ids(RubyLLM::Content.new(self.content))
    end
  end

  def with_attachment_ids(content)
    return content unless attachments.attached?

    ids = attachments.map { { id: it.blob.id, filename: it.blob.filename } }
    text = "#{content.text}\n\n(files attached: #{ids.to_json})"
    content.instance_variable_set(:@text, text)

    content
  end
end
