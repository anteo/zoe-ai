module Chats
  class HistoryListComponent < ApplicationComponent
    Entry = Data.define(:chat, :index, :day_label, :time_span, :message_count, :preview)

    attr_reader :history_chats

    def initialize(history_chats:)
      @history_chats = history_chats
    end

    def entries
      @entries ||= begin
        chats = history_chats.to_a
        messages_by_chat = load_messages(chats)

        chats.each_with_index.map do |chat, index|
          messages = messages_by_chat[chat.id] || []
          first_message = messages.first
          last_message = messages.last

          Entry.new(
            chat:,
            index:,
            day_label: I18n.l(chat.created_at.to_date),
            time_span: format_time_span(chat:, first_message:, last_message:),
            message_count: messages.size,
            preview: last_message&.human_content.to_s.squish
          )
        end
      end
    end

    def empty?
      entries.empty?
    end

    private

    def load_messages(chats)
      chat_ids = chats.map(&:id)
      return {} if chat_ids.empty?

      Message.visible
             .where(chat_id: chat_ids)
             .order(:created_at)
             .group_by(&:chat_id)
    end

    def format_time_span(chat:, first_message:, last_message:)
      if first_message && last_message
        "#{first_message.created_at.strftime("%H:%M")} - #{last_message.created_at.strftime("%H:%M")}"
      else
        chat.created_at.strftime("%H:%M")
      end
    end
  end
end
