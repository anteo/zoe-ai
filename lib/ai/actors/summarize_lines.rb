module AI::Actors
  class SummarizeLines < Actor
    using Rainbow

    input :lines
    input :chunk_size, default: -> { 10000 }
    input :initiator, type: ::Character
    input :companion, type: ::Character
    input :group_by,
          inclusion: %i[date],
          default: :date
    output :summary

    def call
      lines = self.lines.sort_by(&:created_at)
      text = lines.map { |line| format_line(line) }.join("\n\n")
      chunks = AI::Chunker.recursive_text(text, chunk_size:)
      self.summary = if chunks.empty?
        ""
      elsif chunks.size > 1
        chunk_summaries = chunks.map do |chunk|
          prompt = chunk_prompt(chunk.text)
          puts prompt.faint
          summary = summarize(prompt)
          puts summary.faint.green
          summary
        end
        prompt = summary_prompt(chunk_summaries.join("\n\n"))
        puts prompt.faint
        summarize(prompt)
      else
        prompt = chunk_prompt(chunks.first.text)
        puts prompt.faint
        summarize(prompt)
      end
      puts summary.faint.green
    end

    def summarize(prompt)
      AI.chat.with_temperature(0.1).ask(prompt).content
    end

    def format_line(line)
      case group_by
      when :date
        line.to_timestamp_message
      else
        line.to_direct_speech
      end
    end

    def chunk_prompt(text)
      additional_prompt = case group_by
      when :date
        ", saving information about the date and time of day, without breaking down by minute"
      else
        ""
      end
      <<~PROMPT
        For this part of the dialogue #{initiator.name} with #{companion.name}:

        #{text}

        Write a summary#{additional_prompt}:
      PROMPT
    end

    def summary_prompt(text)
      additional_prompt = case group_by
      when :date
        ", saving information about the current date and time"
      else
        ""
      end

      <<~PROMPT
        Parts of the dialogue between #{initiator.name} and #{companion.name} are summarized:

        #{text}

        Combine these parts into one summary#{additional_prompt}:
      PROMPT
    end
  end
end
