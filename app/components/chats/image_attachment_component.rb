# frozen_string_literal: true

module Chats
  class ImageAttachmentComponent < ApplicationComponent
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

    def image_url
      rails_blob_path(attachment, disposition: "inline")
    end

    def image_class
      "h-64 rounded-3xl object-cover"
    end

    def prompt
      attachment.metadata["prompt"]
    end
  end
end