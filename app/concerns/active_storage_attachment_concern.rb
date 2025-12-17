module ActiveStorageAttachmentConcern
  extend ActiveSupport::Concern

  def image?
    content_type&.start_with?("image/")
  end
end
