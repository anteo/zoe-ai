class TTSAudioController < ApplicationController
  def show
    entry = Rails.cache.read(cache_key)
    return head :not_found if entry.blank?

    begin
      send_data entry.fetch(:data), type: entry[:mime_type].presence || mime_type, disposition: "inline"
    ensure
      Rails.cache.delete(cache_key)
    end
  end

  private

  def cache_key
    AI::Speech.cache_key(params[:token].to_s)
  end

  def mime_type
    params[:mime_type].presence || "audio/mpeg"
  end
end
