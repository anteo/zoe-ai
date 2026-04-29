class SettingProvidersComponent < ApplicationComponent
  def providers = Setting.ai.providers
end
