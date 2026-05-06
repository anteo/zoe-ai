class Message < ApplicationRecord
  acts_as_message

  has_many_attached :attachments
  has_many :facts, dependent: :delete_all

  belongs_to :character, optional: true

  before_save :set_character
  before_create :inherit_memorize
  after_commit :append_chat_history_message_metadata, on: [ :create, :update ]
  after_destroy_commit :refresh_chat_history_message_metadata

  scope :visible, -> {
    attachments = ActiveStorage::Attachment.arel_table
    has_attachment = attachments.project(attachments[:record_id])
                                .where(attachments[:record_type].eq("Message"))
                                .distinct
    where(role: %w[user assistant])
      .where(arel_table[:content].not_eq("").or(arel_table[:id].in(has_attachment)))
  }
  scope :history_visible, -> { where(role: %w[user assistant]).where.not(content: [ nil, "" ]) }

  def self.humanize_content(content)
    content.gsub(/\n*\(files attached: \[.*?\]\)/m, "").rstrip
  end

  def user?
    role == "user"
  end

  def assistant?
    role == "assistant"
  end

  def visible?
    (user? || assistant?) && (content.present? || attachments.attached?)
  end

  def to_direct_speech(**)
    I18n.t(:direct_speech, character:, text: content, **)
  end

  def to_timestamp_message
    "#{I18n.l(created_at)}:\n#{to_direct_speech}"
  end

  def destroy_later_messages
    chat.messages.where("id > ?", id).destroy_all
  end

  def human_content
    self.class.humanize_content(content)
  end

  private

  def inherit_memorize
    return if user?
    last_user_message = chat.messages.where(role: "user").last
    self.memorize = last_user_message.nil? || last_user_message.memorize
  end

  def set_character
    self.character = if user?
      chat.character
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

  def append_chat_history_message_metadata
    return unless role.in?(%w[user assistant]) && content.present?

    chat = Chat.find_by(id: chat_id)
    return unless chat

    updates = {
      last_visible_message_id: id,
      last_visible_message_at: created_at
    }

    if chat.first_visible_message_id.blank?
      updates[:first_visible_message_id] = id
      updates[:first_visible_message_at] = created_at
    end

    chat.update_columns(updates) if updates.any?
  end

  def refresh_chat_history_message_metadata
    Chat.find_by(id: chat_id)&.refresh_history_message_metadata!
  end
end
