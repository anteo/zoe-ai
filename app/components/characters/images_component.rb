module Characters
  class ImagesComponent < SectionComponent
    def badge_count
      image_attachments.count
    end

    def image_attachments
      @image_attachments ||= character.images.attachments.includes(:blob).order(created_at: :desc)
    end

    def section_icon_class
      "icon-[lucide--images]"
    end

    def section_data
      { existing_images_json: existing_images.to_json }
    end

    def section_tab_badge_data
      { characters_images_target: "countBadge" }
    end

    def existing_images
      @existing_images ||= image_attachments.map do |attachment|
        {
          full_url: controller.rails_blob_path(attachment, disposition: "inline"),
          height: attachment.height,
          id: attachment.id,
          url: controller.url_for(attachment.variant(resize_to_limit: [ 1200, 1200 ])),
          filename: attachment.filename.to_s,
          description: attachment.description,
          width: attachment.width
        }
      end
    end
  end
end
