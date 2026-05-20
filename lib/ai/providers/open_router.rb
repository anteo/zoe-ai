module AI
  module Providers
    class OpenRouter < RubyLLM::Providers::OpenRouter
      # Map size string to aspect ratio string supported by OpenRouter.
      # size format: "1024x1024", "512x512", etc.
      # Returns aspect ratio string like "1:1", "16:9", etc.
      def size_to_aspect_ratio(size)
        ratios = {
          "1:1" => 1.0,
          "2:3" => 2.0 / 3.0,
          "3:2" => 3.0 / 2.0,
          "3:4" => 3.0 / 4.0,
          "4:3" => 4.0 / 3.0,
          "4:5" => 4.0 / 5.0,
          "5:4" => 5.0 / 4.0,
          "9:16" => 9.0 / 16.0,
          "16:9" => 16.0 / 9.0,
          "21:9" => 21.0 / 9.0
        }

        w, h = size.split("x").map(&:to_f)
        current_ratio = w / h

        ratios.min_by { |_, value| (value - current_ratio).abs }.first
      end

      # Converts the size format like "1024x1024" to "1K", "2K", "4K", "0.5K"
      def size_to_image_size(size)
        options = {
          0.5 => "0.5K",
          1 => "1K",
          2 => "2K",
          4 => "4K"
        }

        dims = size.split("x").map(&:to_f)
        k_value = dims.max / 1024

        closest_k = options.keys.min_by { (it - k_value).abs }

        options[closest_k]
      end

      def render_image_payload(prompt, model:, size:, with: nil, mask: nil, params: {}) # rubocop:disable Lint/UnusedMethodArgument,Metrics/ParameterLists
        prompt = if Array.wrap(with).compact.any?
          content = RubyLLM::Content.new(prompt, with)
          format_content(content)
        else
          prompt
        end

        {
          model: model,
          messages: [
            {
              role: "user",
              content: prompt
            }
          ],
          modalities: %w[image text],
          image_config: {
            aspect_ratio: size_to_aspect_ratio(size),
            image_size: size_to_image_size(size)
          }
        }.deep_merge(params)
      end

      def validate_paint_inputs!(with:, mask:)
        super
        raise ArgumentError, "OpenRouter does not support mask-based image editing" if mask.present?
      end
    end
  end
end
