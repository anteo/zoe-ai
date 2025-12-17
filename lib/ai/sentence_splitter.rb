module AI
  class SentenceSplitter
    class Sentence
      attr_reader :text

      def initialize(text)
        @text = text
      end

      def question?
        @text.match /\?!?\s*[\p{Emoji}]*\s*$/
      end

      def length
        text.size
      end

      def to_s
        text
      end

      # Serialization support for ActiveJob
      class Serializer < ActiveJob::Serializers::ObjectSerializer
        def serialize?(argument)
          argument.is_a?(Sentence)
        end

        def serialize(sentence)
          super(
            "text" => sentence.text
          )
        end

        def deserialize(hash)
          Sentence.new(hash["text"])
        end
      end
    end

    attr_reader :text

    def initialize(text)
      @text = text
    end

    def segmenter
      @segmenter ||= PragmaticSegmenter::Segmenter.new(text:, language: "ru_emoji")
    end

    def sentences
      segmenter.segment.map { Sentence.new(_1) }
    end
  end
end
