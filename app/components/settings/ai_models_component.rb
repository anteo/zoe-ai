module Settings
  class AIModelsComponent < SectionComponent
    form_enabled true
    form_scope "ai.models"
    icon_class "icon-[lucide--bot]"
    parent_section :ai
  end
end
