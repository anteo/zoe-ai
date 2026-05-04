# frozen_string_literal: true

module Characters
  class ImagesComponent < ApplicationComponent
    attr_reader :character, :partner

    def initialize(character:, partner: nil)
      @character = character
      @partner = partner
    end

    def image_attachments
      @image_attachments ||= character.images.attachments.includes(:blob).order(created_at: :desc)
    end

    def existing_images
      @existing_images ||= image_attachments.map do |attachment|
        {
          id: attachment.id,
          url: helpers.url_for(attachment.variant(resize_to_limit: [ 1200, 1200 ])),
          filename: attachment.filename.to_s,
          description: attachment.description
        }
      end
    end
  end
end
