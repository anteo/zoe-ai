# frozen_string_literal: true

class ChatTranscriptionsController < ApplicationController
  def create
    audio = params[:audio]
    return head(:bad_request) if audio.blank?

    transcript = transcribe_audio(audio)

    render json: { text: transcript }
  rescue RubyLLM::Error, RubyLLM::ModelNotFoundError, RubyLLM::UnsupportedAttachmentError => e
    system_logger.error("Voice transcription failed: #{e.message}")
    render_error(e.message)
  end

  private

  def render_error(error)
    payload = { error: error.to_s }
    render json: payload, status: :unprocessable_entity
  end

  def transcribe_audio(audio)
    Tempfile.create(["voice-transcription", File.extname(audio.original_filename.to_s).presence || ".webm"], binmode: true) do |file|
      audio.tempfile.rewind
      IO.copy_stream(audio.tempfile, file)
      file.flush
      RubyLLM.transcribe(file.path).text.to_s.strip
    end
  end
end
