class Message < ApplicationRecord
  acts_as_message

  has_many_attached :attachments
  has_many :facts, dependent: :destroy

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
    where(role: %w[user assistant error])
      .where(arel_table[:content].not_eq("").or(arel_table[:id].in(has_attachment)))
  }
  scope :history_visible, -> { where(role: %w[user assistant error]).where.not(content: [ nil, "" ]) }

  def self.humanize_content(content)
    content.gsub(/\n*\(files attached: \[.*?\]\)/m, "").rstrip
  end

  def user?
    role == "user"
  end

  def assistant?
    role == "assistant"
  end

  def error?
    role == "error"
  end

  def visible?
    (user? || assistant? || error?) && (content.present? || attachments.attached?)
  end

  def replayable_for_llm?
    return false if error?
    return true if tool_call_id.present?
    return true if content_raw.present?
    return true if content.present?
    return true if attachments.attached?

    false
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
    return if user? || error?
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
      llm_content = super
      return llm_content unless llm_content.is_a?(RubyLLM::Content)

      with_attachment_ids(llm_content)
    elsif content_raw.present?
      RubyLLM::Content::Raw.new(content_raw)
    elsif content.present? || attachments.attached?
      with_attachment_ids(RubyLLM::Content.new(content.to_s))
    else
      RubyLLM::Content.new(content)
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
    return unless role.in?(%w[user assistant error]) && content.present?

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
