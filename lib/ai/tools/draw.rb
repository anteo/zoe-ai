module AI
  module Tools
    class Draw < Tool
      using Rainbow

      description "Draw a picture by using a prompt."

      params do
        string :prompt, description: "Detailed prompt describing the picture. Use only English language and avoid using proper names.", required: true
        string :aspect_ratio, description: "Aspect ratio of the image", enum: %w[1:1 2:3 3:2 3:4 4:3 4:5 5:4 9:16 16:9], required: false
        string :image_size, description: "Image size", enum: %w[0.5K 1K 2K 4K], required: false
        string :model, description: "Image generation model to use (do not specify unless explicitly requested)", enum: Draw.models, required: false
      end

      def self.models
        RubyLLM.models.image_models.by_provider("openrouter").map(&:id)
      end

      def make_image_size(ratio, size)
        size = size.delete_suffix("K").to_f
        w_ratio, h_ratio = ratio.split(":").map(&:to_i)
        min_ratio = [w_ratio, h_ratio].min
        base = size * 1024
        width = (base * w_ratio / min_ratio).to_i
        height = (base * h_ratio / min_ratio).to_i
        "#{width}x#{height}"
      end

      def execute(prompt:, aspect_ratio: "1:1", image_size: "2K", model: nil)
        size = make_image_size(aspect_ratio, image_size)
        image = AI.paint(prompt, size: size, model: model)
        if image.data
          # Print the iTerm2 inline image escape sequence
          # ESC ] 1337 ; File = [arguments] : [base64_data] ^G
          # print "\e]1337;File=inline=1:#{image.data}\a\n"

          chat.attachments_to_persist << {
            io: StringIO.new(image.to_blob),
            filename: "generated_image_#{Time.now.to_i}.png",
            content_type: image.mime_type,
            metadata: { prompt:, size:, aspect_ratio:, image_size:, model: }
          }
          "Picture has been successfully generated and displayed to the user"
        else
          "Failed to generate picture"
        end
      end
    end
  end
end
