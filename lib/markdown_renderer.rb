module MarkdownRenderer
  def self.build(escape_html: false)
    renderer = Redcarpet::Render::HTML.new(
      hard_wrap: true, escape_html:, safe_links_only: escape_html,
      link_attributes: { target: "_blank", rel: "noopener" },
    )
    Redcarpet::Markdown.new(
      renderer, fenced_code_blocks: true, tables: true, strikethrough: true,
      autolink: true, no_intra_emphasis: true,
    )
  end
end
