module TurboStreams
  module RedirectHelper
    def redirect(url)
      turbo_stream_action_tag("redirect", url:)
    end
  end
end

Turbo::Streams::TagBuilder.prepend(TurboStreams::RedirectHelper)
