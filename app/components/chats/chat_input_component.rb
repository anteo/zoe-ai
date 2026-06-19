module Chats
  class ChatInputComponent < ApplicationComponent
    attr_reader :chat, :current_character, :transcription_mode, :tts_enabled

    def initialize(chat:, current_character:, transcription_mode: "off", tts_enabled: false)
      @chat = chat
      @current_character = current_character
      @transcription_mode = transcription_mode
      @tts_enabled = ActiveModel::Type::Boolean.new.cast(tts_enabled)
    end

    def tts_available?
      AI.tts_enabled?
    end

    def transcription_available?
      AI.transcription_enabled?
    end
  end
end
