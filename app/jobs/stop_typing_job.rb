# frozen_string_literal: true

class StopTypingJob < ApplicationJob
  include JobChatSupport

  queue_as :default

  def perform(chat)
    remove_message_placeholder(chat)

    TypeSentenceJob.cancel(chat)
    RespondJob.cancel(chat)
  end
end
