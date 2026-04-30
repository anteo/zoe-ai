class Settings::BodyComponent < ApplicationComponent
  SECTIONS = {
    "app" => { icon: "icon-[lucide--settings]" },
    "ai" => { icon: "icon-[lucide--sparkles]" },
    "mailer" => { icon: "icon-[lucide--mail]" },
    "ui" => { icon: "icon-[lucide--monitor]" },
    "events" => { icon: "icon-[lucide--history]" }
  }.freeze

  def initialize(section: nil)
    @section = SECTIONS.key?(section.to_s) ? section.to_s : SECTIONS.keys.first
  end

  def active?(key)
    @section == key
  end
end
