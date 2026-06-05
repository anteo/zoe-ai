module AI
  module Providers
    class OpenRouter < RubyLLM::Providers::OpenRouter
      SUPPORTED_GEMINI_SCHEMA_KEYS = %w[
        description
        enum
        format
        items
        maximum
        minimum
        nullable
        properties
        required
        type
      ].freeze

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

      def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil,
                         thinking: nil, tool_prefs: nil)
        payload = super
        return payload unless gemini_model?(model)
        return payload if payload[:tools].blank?

        payload[:tools] = payload[:tools].map { sanitize_tool_schema(it) }
        payload
      end

      def validate_paint_inputs!(with:, mask:)
        super
        raise ArgumentError, "OpenRouter does not support mask-based image editing" if mask.present?
      end

      private

      def gemini_model?(model)
        model.id.to_s.start_with?("google/")
      end

      def sanitize_tool_schema(tool)
        function = tool[:function] || tool["function"]
        return tool unless function

        parameters = function[:parameters] || function["parameters"]
        return tool unless parameters.is_a?(Hash)

        sanitized = Marshal.load(Marshal.dump(tool))
        sanitized_function = sanitized[:function] || sanitized["function"]
        set_hash_value!(sanitized_function, "parameters", sanitize_schema(parameters))
        sanitized
      end

      def sanitize_schema(schema)
        schema = schema.deep_stringify_keys.slice(*SUPPORTED_GEMINI_SCHEMA_KEYS)

        type = schema["type"].to_s.downcase

        normalize_enum!(schema)
        normalize_numeric_type!(schema)

        if schema["properties"].is_a?(Hash)
          schema["properties"] = schema["properties"].to_h do |name, property|
            [ name.to_s, sanitize_schema(property) ]
          end

          property_keys = schema["properties"].keys
          required = Array(schema["required"]).map(&:to_s) & property_keys
          schema["required"] = required if required.any?
          schema.delete("required") if required.empty?
        else
          schema.delete("properties")
          schema.delete("required")
        end

        if schema["items"].is_a?(Hash)
          schema["items"] = sanitize_schema(schema["items"])
        else
          schema.delete("items") unless type == "array"
        end

        schema
      end

      def normalize_enum!(schema)
        enum = schema["enum"]
        return unless enum.is_a?(Array)

        # Gemini schema validation is stricter than the OpenAI-compatible tool format
        # OpenRouter accepts. Numeric/mixed enums from MCP tools are a likely failure point.
        schema.delete("enum") unless enum.all? { it.is_a?(String) }
      end

      def normalize_numeric_type!(schema)
        return unless schema["type"].to_s.downcase == "number"

        enum = schema["enum"]
        minimum = schema["minimum"]
        maximum = schema["maximum"]

        integer_like_enum = enum.blank? || enum.all? { integer_like_number?(it) }
        integer_like_bounds = [ minimum, maximum ].compact.all? { integer_like_number?(it) }

        schema["type"] = "integer" if integer_like_enum && integer_like_bounds
      end

      def integer_like_number?(value)
        value.is_a?(Integer) || (value.is_a?(Float) && value.finite? && value == value.to_i)
      end

      def set_hash_value!(hash, key, value)
        actual_key = hash.key?(key) ? key : key.to_sym
        hash[actual_key] = value
      end
    end
  end
end
