module ActiveStorageAttachmentConcern
  extend ActiveSupport::Concern

  included do
    accepts_nested_attributes_for :blob, update_only: true
  end

  def image?
    content_type&.start_with?("image/")
  end

  def description
    blob.metadata["description"].to_s
  end

  def description=(value)
    metadata = blob.metadata || {}
    text = value.to_s.strip

    if text.present?
      metadata["description"] = text
    else
      metadata.delete("description")
    end

    blob.metadata = metadata
  end
end
