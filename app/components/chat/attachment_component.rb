# frozen_string_literal: true

class Chat::AttachmentComponent < ApplicationComponent
  attr_reader :attachment

  def initialize(attachment:)
    @attachment = attachment
  end

  def filename
    attachment.filename
  end

  def byte_size
    attachment.byte_size
  end

  def url
    rails_blob_path(attachment, disposition: "attachment")
  end
end