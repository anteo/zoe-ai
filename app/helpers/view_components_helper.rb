module ViewComponentsHelper
  LEGACY_COMPONENT_KEYS = {
    modal: :"ui/modal",
    flash_alert: :"ui/flash_alert",
    error: :"ui/error",
    profile_menu: :"ui/profile_menu",
    avatar_input: :"ui/avatar_input",
    admin_console_modal: :"ui/admin_console_modal",
    chat: :"chat/chat",
    message: :"chat/message",
    message_placeholder: :"chat/message_placeholder",
    chat_input: :"chat/chat_input",
    token_usage_gauge: :"chat/token_usage_gauge",
    attachment: :"chat/attachment",
    image_attachment: :"chat/image_attachment",
    history_drawer: :"chat/history_drawer",
    history_chat_list: :"chat/history_list",
    history_chat_detail: :"chat/history_detail",
    character_selector: :"characters/selector",
    character_details: :"characters/details",
    character_description: :"characters/description",
    character_facts: :"characters/facts",
    character_events: :"characters/events",
    character_images: :"characters/images",
    character_instructions: :"characters/instructions",
    settings_body: :"settings/body",
    setting_app: :"settings/app",
    setting_ai: :"settings/ai",
    setting_ui: :"settings/ui",
    setting_providers: :"settings/providers",
    setting_events: :"settings/events",
    setting_mailer: :"settings/mailer"
  }.freeze

  def component(name, **args, &block)
    namespaced_name = LEGACY_COMPONENT_KEYS.fetch(name.to_sym, name).to_s
    component_class = "#{namespaced_name}_component".classify.safe_constantize

    raise "Component #{name}_component not found!" unless component_class

    render component_class.new(**args), &block
  end
end
