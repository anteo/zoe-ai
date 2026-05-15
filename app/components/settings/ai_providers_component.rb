module Settings
  class AIProvidersComponent < SectionComponent
    form_enabled true
    form_html do
      {
        data: {
          controller: "admin-console-opener",
          action: "submit->admin-console-opener#open",
          admin_console_opener_admin_console_modal_outlet: "#admin-console-modal"
        }
      }
    end
    form_scope "ai.providers"
    icon_class "icon-[lucide--plug]"
    parent_section :ai
  end
end
