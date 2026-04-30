class Settings::ProvidersComponent < ApplicationComponent
  def providers = Setting.ai.providers
end
