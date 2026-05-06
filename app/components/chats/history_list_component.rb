module Chats
  class HistoryListComponent < ApplicationComponent
    Entry = Data.define(:chat, :index, :day_label, :time_span, :message_count, :preview)

    attr_reader :history_chats, :query

    def initialize(history_chats:, query: nil)
      @history_chats = history_chats
      @query = query.to_s
    end

    def entries
      @entries ||= begin
        chats = history_chats.to_a
        counts_by_chat = load_message_counts(chats)

        chats.each_with_index.map do |chat, index|
          Entry.new(
            chat:,
            index:,
            day_label: I18n.l(chat.created_at.to_date),
            time_span: format_time_span(chat:),
            message_count: counts_by_chat[chat.id].to_i,
            preview: chat.last_visible_message&.human_content.to_s.squish
          )
        end
      end
    end

    def empty?
      entries.empty?
    end

    def searching?
      query.present?
    end

    private

    def load_message_counts(chats)
      chat_ids = chats.map(&:id)
      return {} if chat_ids.empty?

      Message.history_visible
             .where(chat_id: chat_ids)
             .group(:chat_id)
             .count
    end

    def format_time_span(chat:)
      if chat.first_visible_message_at && chat.last_visible_message_at
        "#{chat.first_visible_message_at.strftime("%H:%M")} - #{chat.last_visible_message_at.strftime("%H:%M")}"
      else
        chat.created_at.strftime("%H:%M")
      end
    end
  end
end
