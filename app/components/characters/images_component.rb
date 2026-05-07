module Characters
  class ImagesComponent < ApplicationComponent
    attr_reader :character, :editable, :partner

    def initialize(character:, partner: nil, editable: false)
      @character = character
      @editable = editable
      @partner = partner
    end

    def image_attachments
      @image_attachments ||= character.images.attachments.includes(:blob).order(created_at: :desc)
    end

    def existing_images
      @existing_images ||= image_attachments.map do |attachment|
        {
          full_url: helpers.rails_blob_path(attachment, disposition: "inline"),
          height: attachment.height,
          id: attachment.id,
          url: helpers.url_for(attachment.variant(resize_to_limit: [ 1200, 1200 ])),
          filename: attachment.filename.to_s,
          description: attachment.description,
          width: attachment.width
        }
      end
    end
  end
end
