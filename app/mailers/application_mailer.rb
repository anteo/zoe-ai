class ApplicationMailer < ActionMailer::Base
  before_action :attach_brand_icon

  layout "mailer"

  private

  def attach_brand_icon
    path = Rails.root.join("app/assets/images/favicon.png")
    return unless File.exist?(path)
    return if attachments["favicon.png"].present?

    attachments.inline["favicon.png"] = {
      mime_type: "image/png",
      content: File.binread(path)
    }
  end
end
