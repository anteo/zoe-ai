# frozen_string_literal: true

module AI
  module Providers
    # OpenAI-compatible image provider backed by a local ChatGPT OAuth proxy.
    class ChatGPT < RubyLLM::Providers::OpenAI
      MODEL_ID = "chatgpt/gpt-image-2"
      UPSTREAM_MODEL_ID = "gpt-image-2"

      MIN_PIXELS = 655_360
      MAX_PIXELS = 8_294_400
      MAX_EDGE = 3_840
      DIMENSION_STEP = 16

      MAX_REFERENCE_IMAGES = 5
      MAX_REFERENCE_IMAGE_BYTES = 50.megabytes
      REFERENCE_IMAGE_MIME_TYPES = %w[image/jpeg image/png image/webp].freeze

      def initialize(config)
        provider_config = config.dup
        provider_config.request_timeout = config.chatgpt_request_timeout
        super(provider_config)
      end

      def api_base
        @config.chatgpt_api_base
      end

      def headers
        {}
      end

      def list_models
        [
          RubyLLM::Model::Info.new(
            id: MODEL_ID,
            name: "GPT Image 2 (ChatGPT subscription)",
            provider: slug,
            family: "gpt-image-2",
            modalities: { input: %w[text image], output: %w[image] },
            metadata: { source: "chatgpt_oauth", upstream_model_id: UPSTREAM_MODEL_ID }
          )
        ]
      end

      def normalize_image_size(size)
        return "auto" if size.to_s == "auto"

        width, height = parse_image_size(size)
        requested_ratio = width.fdiv(height)
        validate_aspect_ratio!(requested_ratio)

        target_pixels = (width * height).clamp(MIN_PIXELS, MAX_PIXELS)
        supported_dimensions(requested_ratio, target_pixels).join("x")
      end

      def render_image_payload(prompt, model:, size:, with: nil, mask: nil, params: {})
        normalized_size = normalize_image_size(size)
        normalized_params = params
        normalized_params = params.merge(size: normalized_size) if reference_images?(with)

        super(
          prompt,
          model: upstream_model_id(model),
          size: normalized_size,
          with:,
          mask:,
          params: normalized_params
        )
      end

      def validate_paint_inputs!(with:, mask:)
        raise ArgumentError, "ChatGPT OAuth does not support mask-based image editing" if mask.present?

        super(with:, mask:)

        references = Array.wrap(with).compact
        if references.size > MAX_REFERENCE_IMAGES
          raise ArgumentError, "ChatGPT OAuth supports at most #{MAX_REFERENCE_IMAGES} reference images"
        end

        references.each { validate_reference_image!(it) }
      end

      class << self
        def configuration_options
          %i[chatgpt_api_base chatgpt_enabled chatgpt_request_timeout]
        end

        def configuration_requirements
          %i[chatgpt_api_base chatgpt_enabled chatgpt_request_timeout]
        end
      end

      private

      def parse_image_size(size)
        match = size.to_s.match(/\A(\d+)x(\d+)\z/)
        raise ArgumentError, "Image size must use WIDTHxHEIGHT format" unless match

        width, height = match.captures.map(&:to_i)
        raise ArgumentError, "Image dimensions must be greater than zero" if width.zero? || height.zero?

        [ width, height ]
      end

      def validate_aspect_ratio!(ratio)
        return if ratio.between?(1.0 / 3.0, 3.0)

        raise ArgumentError, "ChatGPT image aspect ratio must be between 1:3 and 3:1"
      end

      def supported_dimensions(requested_ratio, target_pixels)
        candidates = (DIMENSION_STEP..MAX_EDGE).step(DIMENSION_STEP).filter_map do |width|
          height = round_to_step(width / requested_ratio)
          next unless height.between?(DIMENSION_STEP, MAX_EDGE)

          pixels = width * height
          next unless pixels.between?(MIN_PIXELS, MAX_PIXELS)

          ratio_error = ((width.fdiv(height) - requested_ratio) / requested_ratio).abs
          area_error = (pixels - target_pixels).abs.fdiv(target_pixels)

          [ (ratio_error * 4) + area_error, width, height ]
        end

        candidate = candidates.min_by(&:first)
        raise ArgumentError, "Image size cannot be normalized for ChatGPT" unless candidate

        candidate.drop(1)
      end

      def round_to_step(value)
        [(value / DIMENSION_STEP).round * DIMENSION_STEP, DIMENSION_STEP].max
      end

      def upstream_model_id(model)
        model.to_s == MODEL_ID ? UPSTREAM_MODEL_ID : model
      end

      def reference_images?(with)
        Array.wrap(with).compact.any?
      end

      def validate_reference_image!(source)
        attachment = RubyLLM::Attachment.new(source)
        unless REFERENCE_IMAGE_MIME_TYPES.include?(attachment.mime_type)
          raise RubyLLM::UnsupportedAttachmentError, attachment.mime_type
        end

        byte_size = reference_image_byte_size(source, attachment)
        return if byte_size <= MAX_REFERENCE_IMAGE_BYTES

        raise ArgumentError, "Reference image #{attachment.filename} exceeds the 50 MB limit"
      end

      def reference_image_byte_size(source, attachment)
        return source.byte_size if source.respond_to?(:byte_size)
        return source.blob.byte_size if source.respond_to?(:blob) && source.blob.respond_to?(:byte_size)

        attachment.content.to_s.bytesize
      end
    end
  end
end
