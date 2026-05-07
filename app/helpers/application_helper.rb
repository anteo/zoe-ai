module ApplicationHelper
  def turbo_modal_frame?
    request&.headers&.[]("Turbo-Frame") == "modal"
  end

  def markdown(text)
    return "" if text.blank?
    renderer = Redcarpet::Render::HTML.new(hard_wrap: true, link_attributes: { target: "_blank", rel: "noopener" })
    Redcarpet::Markdown.new(renderer, fenced_code_blocks: true, tables: true, strikethrough: true, autolink: true, no_intra_emphasis: true)
                       .render(text).html_safe
  end


  def avatar_for(url: nil, css_class: "w-8 h-8", content: nil, id: nil)
    css = "rounded-full shrink-0 object-cover shadow-md #{css_class}"
    size_px = avatar_size_px_from_class(css_class)

    if url
      image_tag(url, class: css, id:)
    else
      font_size = [ (size_px * 0.375).round, 12 ].max
      tag.span(
        content,
        class: "#{css} bg-base-100 flex items-center justify-center font-bold",
        style: "font-size: #{font_size}px;"
      )
    end
  end

  def avatar_for_user(user, css_class: "w-8 h-8", id: nil, fallback: false)
    size_px = avatar_size_px_from_class(css_class)
    url = attached_avatar_variant_url(user&.avatar, size_px) unless fallback
    avatar_for(url: url || user&.gravatar_url(size: size_px), content: user&.initials, css_class:, id:)
  end

  def avatar_for_character(character, css_class: "w-8 h-8", id: nil, fallback: false)
    size_px = avatar_size_px_from_class(css_class)

    if character.new_record?
      avatar_for(content: tag.span(class: "icon-[lucide--plus]"), css_class:, id:)
    else
      url = attached_avatar_variant_url(character.avatar, size_px) unless fallback
      avatar_for(url:, content: character.name[0].upcase, css_class:, id:)
    end
  end

  def link_to_character(character, link, avatar_class: "w-8 h-8", link_class: "", name_class: "", data: nil, name: character.name)
    link_width_px = avatar_size_px_from_class(avatar_class) + 16
    link_class = "rounded-md shrink-0 flex flex-col items-center gap-1 px-1 py-1.5 #{link_class}"
    name_class = "block w-full text-xs font-medium leading-tight text-center whitespace-nowrap overflow-hidden text-ellipsis #{name_class}"

    link_to(link, data:, class: link_class, style: "width: #{link_width_px}px;", aria: { label: name }) do
      safe_join([
                  avatar_for_character(character, css_class: avatar_class),
                  content_tag(:span, name, class: name_class)
                ])
    end
  end

  def link_to_new_character(link, avatar_class: "w-8 h-8", link_class: "", name_class: "", data: nil)
    link_to_character(Character.new, link, avatar_class:, link_class:, name_class:, data:, name: t(:label_new))
  end

  def avatar_size_px_from_class(css_class)
    units = css_class.to_s.scan(/\b[wh]-(\d+(?:\.\d+)?)\b/).flatten.map(&:to_f)
    return 32 if units.empty?

    (units.max * 4).round
  end

  def attached_avatar_variant_url(attachment, size_px)
    blob = attachment&.blob
    return unless blob&.persisted?

    url_for(blob.variant(resize_to_limit: [ size_px * 2 ] * 2))
  end

  def modal_alerts_dom_id(frame_id = nil)
    frame_id ||= turbo_referrer_frame_id
    frame_id.present? ? "modal-alerts-#{frame_id}" : "top-alerts"
  end

  def turbo_stream_flash_alerts(messages: flash, target: nil)
    flash_store = messages.respond_to?(:flash) ? messages.flash : messages
    items = if flash_store.respond_to?(:to_hash)
      flash_store.to_hash.to_a
    elsif flash_store.respond_to?(:to_h)
      flash_store.to_h.to_a
    else
      Array(flash_store)
    end

    target_id = modal_alerts_dom_id(target)
    consumed_keys = []

    rendered = items.filter_map do |type, message|
      next if message.blank?

      consumed_keys << type
      turbo_stream.append(target_id, component(:"ui/flash_alert", type:, message:))
    end

    flash_store.discard(*consumed_keys) if consumed_keys.any? && flash_store.respond_to?(:discard)

    safe_join(rendered)
  end
end
