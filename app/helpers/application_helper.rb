module ApplicationHelper
  def markdown(text)
    return "" if text.blank?
    renderer = Redcarpet::Render::HTML.new(hard_wrap: true, link_attributes: { target: "_blank", rel: "noopener" })
    Redcarpet::Markdown.new(renderer, fenced_code_blocks: true, tables: true, strikethrough: true, autolink: true, no_intra_emphasis: true)
                       .render(text).html_safe
  end

  def avatar_for(url: nil, size: 32, initials: nil, id: nil)
    css = "rounded-full shrink-0 object-cover shadow-md"
    style = "width: #{size}px; height: #{size}px;"

    if url
      image_tag(url, class: css, style:, id:)
    else
      font_size = [ (size / 2.8).round, 12 ].max
      tag.span(
        initials || "?",
        class: "#{css} bg-base-100 flex items-center justify-center font-bold",
        style: "#{style} font-size: #{font_size}px;"
      )
    end
  end

  def avatar_for_user(user, size: 32, id: nil)
    avatar_for(url: user&.gravatar_url(size: size), initials: user&.initials, size:, id:)
  end

  def avatar_for_character(character, size: 32, id: nil)
    url = url_for(character.avatar.variant(resize_to_limit: [ size ] * 2)) if character.avatar.attached?
    avatar_for(url:, initials: character.name[0].upcase, size:, id:)
  end
end
