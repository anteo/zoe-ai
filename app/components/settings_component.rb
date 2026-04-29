class SettingsComponent < ApplicationComponent
  SECTIONS = {
    "providers" => { icon: "icon-[lucide--plug-2]" }
  }.freeze

  def initialize(section: nil)
    @section = section || "providers"
  end

  def active?(key)
    @section == key
  end
end
