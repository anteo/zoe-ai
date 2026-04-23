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

  def avatar_for(url: nil, size: 8, content: nil, id: nil)
    css = "rounded-full shrink-0 object-cover shadow-md w-#{size} h-#{size}"

    if url
      image_tag(url, class: css, id:)
    else
      font_size = [ (size * 1.5).round, 12 ].max
      tag.span(
        content,
        class: "#{css} bg-base-100 flex items-center justify-center font-bold",
        style: "font-size: #{font_size}px;"
      )
    end
  end

  def avatar_for_user(user, size: 8, id: nil)
    avatar_for(url: user&.gravatar_url(size: size * 4), content: user&.initials, size:, id:)
  end

  def avatar_for_character(character, size: 8, id: nil)
    if character.new_record?
      avatar_for(content: tag.span(class: "icon-[lucide--plus]"), size:, id:)
    else
      url = url_for(character.avatar.variant(resize_to_limit: [ size * 8 ] * 2)) if character.avatar.attached?
      avatar_for(url:, content: character.name[0].upcase, size:, id:)
    end
  end

  def link_to_character(character, link, size: 8, link_class: "", name_class: "", data: nil, name: character.name)
    link_class = "rounded-md shrink-0 flex flex-col items-center gap-1 px-1 py-1.5 w-#{size + 4} #{link_class}"
    name_class = "block w-full text-xs font-medium leading-tight text-center whitespace-nowrap overflow-hidden text-ellipsis #{name_class}"

    link_to(link, data:, class: link_class, aria: { label: name }) do
      safe_join([
                  avatar_for_character(character, size:),
                  content_tag(:span, name, class: name_class)
                ])
    end
  end

  def link_to_new_character(link, size: 8, link_class: "", name_class: "", data: nil)
    link_to_character(Character.new, link, size:, link_class:, name_class:, data:, name: t(:label_new))
  end
end
