require "pragmatic_segmenter"

module PragmaticSegmenter
  module Languages
    module RussianWithEmoji
      include Languages::Russian

      class Processor < PragmaticSegmenter::Processor
        private

        def sentence_boundary_regexp
          re = @language::SENTENCE_BOUNDARY_REGEX.to_s
          re.gsub! /\)$/, '\s*[\p{Emoji}]*)'
          Regexp.new(re)
        end

        def sentence_boundary_punctuation(txt)
          txt = Rule.apply txt, @language::ReplaceColonBetweenNumbersRule if defined? @language::ReplaceColonBetweenNumbersRule
          txt = Rule.apply txt, @language::ReplaceNonSentenceBoundaryCommaRule if defined? @language::ReplaceNonSentenceBoundaryCommaRule

          txt.scan(sentence_boundary_regexp)
        end
      end
    end
  end
end