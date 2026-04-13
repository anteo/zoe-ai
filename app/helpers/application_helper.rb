module ApplicationHelper
  def avatar_for(url: nil, size: 128, initials: nil)
    css = "w-8 h-8 rounded-full shrink-0"

    if url
      image_tag(url, class: css)
    else
      tag.span(initials || "?", class: "#{css} bg-base-100 flex items-center justify-center text-xs font-medium shadow-sm")
    end
  end

  def avatar_for_user(user, size: 128)
    avatar_for(url: user&.gravatar_url(size: size), initials: user&.initials, size:)
  end

  def avatar_for_character(character, size: 128)
    url = url_for(character.avatar.variant(resize_to_limit: [size] * 2)) if character.avatar.attached?
    avatar_for(url:, initials: character.name[0], size:)
  end
end
