module AI
  class SentenceSplitter
    PARAGRAPH_BREAK = /(\r?\n(?:[ \t]*\r?\n)+)/
    HTML_TAG = /<!--|<\/?[a-z][a-z0-9:-]*(?=[[:space:]]|\/?>)/i
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
      @max_messages = max_messages || Setting.ui.max_message_bubbles
    end

    def segmenter(source_text)
      PragmaticSegmenter::Segmenter.new(text: source_text, language: "ru_emoji", clean: false)
    end

    def chunks
      source = text.to_s
      return [] if source.blank?
      # An HTML tag can span multiple paragraphs even when Markdown can render each fragment.
      return [ Chunk.new(source) ] if max_messages <= 1 || source.match?(HTML_TAG)

      breaks = split_points(source)
      return [ Chunk.new(source) ] if breaks.empty?

      split_at_safe_boundaries(source, breaks).map { Chunk.new(_1) }
    end

    private

    def split_points(source)
      offset = 0
      source.split(PARAGRAPH_BREAK).each_slice(2).flat_map do |block, separator|
        points = list_block?(block) ? [] : sentence_breaks(block, offset)
        offset += block.length
        next points unless separator

        separator_end = offset + separator.length
        points << (offset...separator_end) unless block.blank? || separator_end == source.length
        offset = separator_end
        points
      end
    end

    def sentence_breaks(block, offset)
      position = 0
      segmenter(block).segment.filter_map do |sentence|
        start = /\G[[:space:]]*/.match(block, position).end(0)
        # The segmenter can normalize text. Only use boundaries aligned with the original source.
        return [] unless block[start, sentence.length] == sentence

        gap = (offset + position)...(offset + start) if position.positive? && start > position
        position = start + sentence.length
        gap
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

    def split_at_safe_boundaries(source, breaks)
      renderer = MarkdownRenderer.build
      offset = 0
      rendered = renderer.render(source)
      chunk_size = ((breaks.size + 1).fdiv(max_messages)).ceil
      parts = []

      breaks.each_slice(chunk_size) do |group|
        next if group.size < chunk_size

        paragraph_break = group.reverse.find { |gap| PARAGRAPH_BREAK.match?(source[gap]) }
        [ group.last, paragraph_break ].compact.uniq.each do |gap|
          left = source[offset...gap.begin]
          right = source[gap.end..]
          next if left.blank? || right.blank?

          right_html = renderer.render(right)
          next unless same_markdown?(rendered, renderer.render(left), right_html, source[gap])

          parts << left
          offset = gap.end
          rendered = right_html
          break
        end
      end
      parts << source[offset..]
    end

    def same_markdown?(original, left_html, right_html, separator)
      return false if left_html.blank? || right_html.blank?

      # A bubble may add a block boundary or divide a paragraph, but must preserve its inline markup.
      return true if original == left_html + right_html || original == "#{left_html}\n#{right_html}"
      return false unless left_html.end_with?("</p>\n") && right_html.start_with?("<p>")

      linebreak_count = separator.count("\n")
      return false if linebreak_count > 1

      joiner = linebreak_count == 1 ? "<br>\n" : separator
      original == left_html.delete_suffix("</p>\n") + joiner + right_html.delete_prefix("<p>")
    end
  end
end
