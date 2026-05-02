module JobSettingsAware
  extend ActiveSupport::Concern

  included do
    before_perform :sync_settings
  end

  private

  def sync_settings
    Setting.sync_hooks_if_stale!(context: { source: :job, job: self.class.name })
  end
end
