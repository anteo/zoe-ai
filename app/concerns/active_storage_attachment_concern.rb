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

  def width
    dimensions["width"]
  end

  def height
    dimensions["height"]
  end

  def dimensions
    return {} unless image?

    ensure_image_dimensions!
    blob.metadata.slice("width", "height")
  rescue ActiveStorage::FileNotFoundError, Errno::ENOENT
    {}
  end

  private

  def ensure_image_dimensions!
    return if blob.metadata["width"].present? && blob.metadata["height"].present?
    return if blob.analyzed?

    blob.analyze
    blob.reload
  end
end
