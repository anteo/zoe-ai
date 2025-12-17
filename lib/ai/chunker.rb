module AI
  class Chunker
    class Chunk
      attr_reader :text

      def initialize(text)
        @text = text
      end
    end

    # Splits text into chunks of approximately chunk_size characters,
    # trying to break at paragraph boundaries (\n\n) then sentence boundaries.
    def self.recursive_text(text, chunk_size: 10000)
      # First split by double newline (paragraphs)
      paragraphs = text.split(/\n\n+/)
      chunks = []
      current_chunk = ""

      paragraphs.each do |para|
        if current_chunk.size + para.size + 2 <= chunk_size
          current_chunk = current_chunk.empty? ? para : "#{current_chunk}\n\n#{para}"
        else
          # If the paragraph itself is larger than chunk_size, split by sentences
          if para.size > chunk_size
            sentences = split_into_sentences(para)
            sentences.each do |sent|
              if current_chunk.size + sent.size + 1 <= chunk_size
                current_chunk = current_chunk.empty? ? sent : "#{current_chunk} #{sent}"
              else
                chunks << Chunk.new(current_chunk) unless current_chunk.empty?
                current_chunk = sent
              end
            end
          else
            # Start a new chunk with this paragraph
            chunks << Chunk.new(current_chunk) unless current_chunk.empty?
            current_chunk = para
          end
        end
      end
      chunks << Chunk.new(current_chunk) unless current_chunk.empty?
      chunks
    end

    private

    # Simple sentence splitting by punctuation followed by space.
    # This is naive; consider using pragmatic_segmenter for better accuracy.
    def self.split_into_sentences(text)
      # Split by . ! ? followed by space or end of string
      text.split(/(?<=[.!?])\s+(?=[A-ZА-Я])|(?<=[.!?])$/).reject(&:empty?)
    end
  end
end