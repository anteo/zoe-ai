module JobLocalePropagation
  extend ActiveSupport::Concern

  included do
    before_enqueue :capture_locale
    around_perform :with_locale
  end

  attr_accessor :job_locale
  private :job_locale, :job_locale=

  def serialize
    super.merge("job_locale" => job_locale || I18n.locale.to_s)
  end

  def deserialize(job_data)
    super
    self.job_locale = job_data["job_locale"]
  end

  def capture_locale
    self.job_locale ||= I18n.locale.to_s
  end

  private

  def with_locale
    I18n.with_locale((job_locale || I18n.default_locale).to_sym) do
      yield
    end
  end
end
