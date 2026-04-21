module AI
  module Tools
    class Draw < Tool
      using Rainbow

      description -> {
        characters = ::ActiveStorage::Attachment
          .where(record_type: "Character")
          .preload(:record, :blob)
          .map { { character: it.record.name, attachment_id: it.blob.id, description: it.blob.metadata[:description] } }

        "Draw a picture by using a prompt. You can provide attachment IDs from chat history or character attachments to use as reference images.\n" +
          "IMPORTANT: For each character, pick AT MOST ONE image — the one whose description best matches the drawing prompt.\n" +
          "Do NOT attach multiple images of the same character. When describing people from reference images, specify which photo they are from to maintain consistency. For example: \"The man from the first reference image (name)\" or \"The woman from the second reference image (name)\".\n" +
          "Crucially, ensure the characters' facial features from the reference images are preserved as accurately as possible. Do not add any new physical traits, facial hair, or characteristics not present in the original images. The goal is to maximize facial resemblance to the reference photos.\n" +
          "Characters available: #{characters.inspect}"
      }

      params do
        string :prompt,
               description: "Detailed prompt describing the picture. Use only English language and avoid using proper names.",
               required: true
        string :aspect_ratio,
               description: "Aspect ratio of the image",
               enum: %w[1:1 2:3 3:2 3:4 4:3 4:5 5:4 9:16 16:9],
               required: false
        string :image_size,
               description: "Image size",
               enum: %w[0.5K 1K 2K 4K],
               required: false
        string :model,
               description: "Image generation model to use (do not specify unless explicitly requested)",
               enum: Draw.models,
               required: false
        array :attachment_ids,
              of: :integer,
              description: "IDs of image attachments to use as reference images. Use at most one image per character — choose the one whose description best fits the drawing prompt.",
              required: false
      end

      def self.models
        RubyLLM.models.image_models.by_provider("openrouter").map(&:id)
      end

      def make_image_size(ratio, size)
        size = size.delete_suffix("K").to_f
        w_ratio, h_ratio = ratio.split(":").map(&:to_i)
        min_ratio = [ w_ratio, h_ratio ].min
        base = size * 1024
        width = (base * w_ratio / min_ratio).to_i
        height = (base * h_ratio / min_ratio).to_i
        "#{width}x#{height}"
      end

      def execute(prompt:, aspect_ratio: "1:1", image_size: "2K", model: nil, attachment_ids: [])
        size = make_image_size(aspect_ratio, image_size)

        # Fetch attachments if provided
        with = attachment_ids.map do |id|
          blob = ActiveStorage::Blob.find_by(id: id)
          fail! "Attachment with ID #{id} not found" unless blob
          blob
        end

        image = AI.paint(prompt, size:, model:, with:)
        if image.data
          # Print the iTerm2 inline image escape sequence
          # ESC ] 1337 ; File = [arguments] : [base64_data] ^G
          # print "\e]1337;File=inline=1:#{image.data}\a\n"

          chat.attachments_to_persist << {
            io: StringIO.new(image.to_blob),
            filename: "generated_image_#{Time.now.to_i}.png",
            content_type: image.mime_type,
            metadata: { prompt:, size:, aspect_ratio:, image_size:, model:, attachment_ids: }
          }
          "Picture has been successfully generated and displayed to the user"
        else
          "Failed to generate picture"
        end
      end
    end
  end
end
