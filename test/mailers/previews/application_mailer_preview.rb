class ApplicationMailerPreview < ActionMailer::Preview
  include Rails.application.routes.url_helpers

  private

  def sample_character
    Character.includes(:author).order(:id).first || Character.new(
      ai: true,
      author: sample_user,
      bio: "A preview AI character.",
      name: "Preview Zoe"
    )
  end

  def sample_email
    "preview@example.com"
  end

  def sample_token(name = "token")
    "#{name}-1234567890"
  end

  def sample_user
    User.order(:id).first || User.new(
      confirmed_at: Time.current,
      email: sample_email,
      first_name: "Preview",
      last_name: "User"
    )
  end

  def default_url_options
    ActionMailer::Base.default_url_options || {}
  end
end
