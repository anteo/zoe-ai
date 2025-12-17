module AI::Actors
  class SummarizeChat < Actor
    input :dialog, type: Dialog

    def call
      result = AI::Actors::SummarizeLines.call(lines: dialog.lines,
                                               initiator: dialog.initiator,
                                               companion: dialog.companion)
      dialog.update(summary: result.summary) if result.success?
    end
  end
end
