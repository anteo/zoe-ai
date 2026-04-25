module AI
  class SentenceSplitter
    DEFAULT_MAX_MESSAGES = 3
    LIST_MARKER_REGEXP = /^\s*(?:[-*+•]|(?:\d+[.)]))\s+/
    INLINE_LIST_ITEM_REGEXP = /\A[\p{Lu}А-ЯЁ][^.!?\n]{0,80}[.!?]\s+\S/

    class Chunk
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
        def klass
          Chunk
        end

        def serialize?(argument)
          argument.is_a?(Chunk)
        end

        def serialize(chunk)
          super(
            "text" => chunk.text
          )
        end

        def deserialize(hash)
          Chunk.new(hash["text"])
        end
      end
    end

    attr_reader :text, :max_messages

    def initialize(text, max_messages: nil)
      @text = text
      @max_messages = max_messages || ENV.fetch("ZOE_MAX_MESSAGE_BUBBLES", DEFAULT_MAX_MESSAGES).to_i
    end

    def segmenter(source_text)
      PragmaticSegmenter::Segmenter.new(text: source_text, language: "ru_emoji")
    end

    def chunks
      units = semantic_units
      return [] if units.empty?

      balanced_units(units).map { Chunk.new(_1) }
    end

    private

    def semantic_units
      blocks = text.to_s.split(/\n{2,}/).map(&:strip).reject(&:blank?)
      blocks.flat_map do |block|
        if list_block?(block)
          block
        else
          segmenter(block).segment.map(&:strip).reject(&:blank?)
        end
      end
    end

    def list_block?(block)
      lines = block.lines.map(&:strip).reject(&:blank?)
      return false if lines.size < 2

      return true if lines.any? { |line| line.match?(LIST_MARKER_REGEXP) }
      return true if lines.first.end_with?(":") && lines.size >= 3

      inline_items_count = lines.count { |line| line.match?(INLINE_LIST_ITEM_REGEXP) }
      inline_items_count >= 3
    end

    def balanced_units(units)
      return units if units.size <= max_messages

      chunk_size = (units.size.to_f / max_messages).ceil
      units.each_slice(chunk_size).map { |slice| join_slice(slice) }
    end

    def join_slice(slice)
      separator = slice.any? { |unit| unit.include?("\n") } ? "\n\n" : " "
      slice.join(separator)
    end
  end
end
