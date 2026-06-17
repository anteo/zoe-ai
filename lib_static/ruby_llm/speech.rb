# frozen_string_literal: true

module RubyLLM
  class Speech
    DEFAULT_PCM_SAMPLE_RATE = 24_000
    MIME_TYPES_BY_RESPONSE_FORMAT = {
      "mp3" => "audio/mpeg",
      "pcm" => "audio/pcm",
      "wav" => "audio/wav"
    }.freeze

    attr_reader :data, :mime_type, :model, :response_format

    def initialize(data:, model: nil, mime_type: nil, response_format: nil)
      @data = data
      @model = model
      @mime_type = mime_type
      @response_format = response_format
    end

    def save(path)
      File.binwrite(File.expand_path(path), data)
      path
    end

    def with_response_format(response_format)
      return self if response_format == self.response_format

      self.class.new(data:, model:, mime_type:, response_format:)
    end

    def normalized
      normalized_mime_type = self.class.normalize_mime_type(mime_type, response_format:)
      return self if normalized_mime_type.empty?

      if self.class.pcm_mime_type?(normalized_mime_type)
        self.class.new(data: self.class.pcm_to_wav(data), model:, mime_type: "audio/wav", response_format: "wav")
      elsif normalized_mime_type == mime_type
        self
      else
        self.class.new(data:, model:, mime_type: normalized_mime_type, response_format:)
      end
    end

    class << self
      def speak(input, model: nil, provider: nil, assume_model_exists: false, voice: nil, context: nil, **options)
        config = context&.config || RubyLLM.config
        model ||= config.default_tts_model
        model, provider_instance = Models.resolve(
          model,
          provider:,
          assume_exists: assume_model_exists,
          config:
        )

        provider_instance.speak(input, model: model.id, voice:, **options).normalized
      end

      def normalize_mime_type(mime_type, response_format: nil)
        mime_type = mime_type.to_s.strip
        if mime_type.empty? || mime_type.match?(/\Aapplication\/octet-stream\b/i)
          MIME_TYPES_BY_RESPONSE_FORMAT.fetch(response_format.to_s, mime_type)
        else
          mime_type
        end
      end

      def pcm_mime_type?(mime_type)
        mime_type.to_s.match?(/pcm/i)
      end

      def pcm_to_wav(data, sample_rate: DEFAULT_PCM_SAMPLE_RATE, channels: 1, bits_per_sample: 16)
        block_align = channels * bits_per_sample / 8
        byte_rate = sample_rate * block_align
        data_size = data.bytesize
        chunk_size = 36 + data_size

        header = [
          "RIFF",
          [ chunk_size ].pack("V"),
          "WAVE",
          "fmt ",
          [ 16 ].pack("V"),
          [ 1 ].pack("v"),
          [ channels ].pack("v"),
          [ sample_rate ].pack("V"),
          [ byte_rate ].pack("V"),
          [ block_align ].pack("v"),
          [ bits_per_sample ].pack("v"),
          "data",
          [ data_size ].pack("V")
        ].join

        header + data.b
      end
    end
  end
end
