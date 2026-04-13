module ApplicationHelper
  def avatar_for(character, size: 128)
    css = "w-8 h-8 rounded-full shrink-0"

    if character&.gravatar_url
      image_tag(character.gravatar_url(size: size), class: css)
    else
      initials = character&.initials || "?"
      tag.span(initials, class: "#{css} bg-base-100 flex items-center justify-center text-xs font-medium shadow-sm")
    end
  end
end
