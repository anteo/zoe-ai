module ApplicationHelper
  def avatar_for(character, size: 128)
    css = "w-8 h-8 rounded-full shrink-0"

    if (url = character&.user&.gravatar_url(size: size))
      image_tag(url, class: css)
    else
      tag.span(character&.initials || "?", class: "#{css} bg-base-100 flex items-center justify-center text-xs font-medium shadow-sm")
    end
  end
end
