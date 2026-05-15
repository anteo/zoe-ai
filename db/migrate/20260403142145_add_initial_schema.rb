class AddInitialSchema < ActiveRecord::Migration[8.1]
  def change
    enable_extension "vector"

    create_table "users", force: :cascade do |t|
      t.boolean "admin", default: false, null: false
      t.datetime "confirmation_sent_at"
      t.string "confirmation_token"
      t.datetime "confirmed_at"
      t.string "email"
      t.string "encrypted_password", default: "", null: false
      t.string "first_name"
      t.string "last_name"
      t.bigint "main_character_id"
      t.string "provider"
      t.datetime "remember_created_at"
      t.datetime "reset_password_sent_at"
      t.string "reset_password_token"
      t.string "uid"
      t.string "unconfirmed_email"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "confirmation_token" ], name: "index_users_on_confirmation_token", unique: true
      t.index [ "email" ], name: "index_users_on_email", unique: true, where: "(email IS NOT NULL)"
      t.index [ "main_character_id" ], name: "index_users_on_main_character_id"
      t.index [ "provider", "uid" ], name: "index_users_on_provider_and_uid", unique: true, where: "((provider IS NOT NULL) AND (uid IS NOT NULL))"
      t.index [ "reset_password_token" ], name: "index_users_on_reset_password_token", unique: true
    end

    create_table "characters", force: :cascade do |t|
      t.boolean "ai", default: false, null: false
      t.bigint "author_id"
      t.string "bio", default: "", null: false
      t.text "description", default: "", null: false
      t.boolean "description_up_to_date", default: false, null: false
      t.boolean "is_default", default: false, null: false
      t.string "name", limit: 50, null: false
      t.boolean "third_party", default: false, null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "author_id" ], name: "index_characters_on_author_id"
      t.index [ "is_default" ], name: "index_characters_on_is_default"
      t.index [ "is_default" ], name: "index_characters_on_single_default_ai", unique: true, where: "((ai = true) AND (is_default = true))"
    end

    create_table "characters_users", id: false, force: :cascade do |t|
      t.bigint "character_id", null: false
      t.bigint "user_id", null: false
      t.index [ "character_id", "user_id" ], name: "index_characters_users_on_character_id_and_user_id", unique: true
      t.index [ "user_id" ], name: "index_characters_users_on_user_id"
    end

    create_table "chats", force: :cascade do |t|
      t.bigint "character_id"
      t.boolean "closed", default: false, null: false
      t.boolean "facts_extracted", default: false, null: false
      t.datetime "first_visible_message_at"
      t.bigint "first_visible_message_id"
      t.datetime "last_visible_message_at"
      t.bigint "last_visible_message_id"
      t.boolean "memorize", default: true, null: false
      t.bigint "model_id"
      t.bigint "partner_id"
      t.text "summary"
      t.bigint "user_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "character_id" ], name: "index_chats_on_character_id"
      t.index [ "first_visible_message_at" ], name: "index_chats_on_first_visible_message_at"
      t.index [ "first_visible_message_id" ], name: "index_chats_on_first_visible_message_id"
      t.index [ "last_visible_message_at" ], name: "index_chats_on_last_visible_message_at"
      t.index [ "last_visible_message_id" ], name: "index_chats_on_last_visible_message_id"
      t.index [ "model_id" ], name: "index_chats_on_model_id"
      t.index [ "partner_id" ], name: "index_chats_on_partner_id"
      t.index [ "user_id" ], name: "index_chats_on_user_id"
    end

    create_table "fact_aggregates", force: :cascade do |t|
      t.date "anchor_month", null: false
      t.text "body", default: "", null: false
      t.bigint "character_id", null: false
      t.integer "facts_count", default: 0, null: false
      t.string "kind", null: false
      t.bigint "parent_id"
      t.bigint "partner_id", null: false
      t.string "slot_key", null: false
      t.datetime "source_updated_at"
      t.boolean "stale", default: false, null: false
      t.text "summary"
      t.datetime "summary_source_updated_at"
      t.string "summary_status", default: "pending", null: false
      t.bigint "topic_id", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "character_id", "partner_id", "kind", "anchor_month" ], name: "idx_fact_aggregates_band_lookup"
      t.index [ "character_id" ], name: "index_fact_aggregates_on_character_id"
      t.index [ "parent_id" ], name: "index_fact_aggregates_on_parent_id"
      t.index [ "partner_id" ], name: "index_fact_aggregates_on_partner_id"
      t.index [ "slot_key" ], name: "idx_fact_aggregates_unique_slot", unique: true
      t.index [ "summary_status" ], name: "index_fact_aggregates_on_summary_status"
      t.index [ "topic_id" ], name: "index_fact_aggregates_on_topic_id"
    end

    create_table "facts", force: :cascade do |t|
      t.bigint "author_id"
      t.bigint "character_id", null: false
      t.bigint "chat_id"
      t.text "content"
      t.date "date_from"
      t.date "date_to"
      t.integer "importance", default: 50
      t.string "kind"
      t.datetime "mentioned_at", precision: nil
      t.bigint "message_id"
      t.date "month", null: false
      t.bigint "partner_id", null: false
      t.boolean "persistent", default: true, null: false
      t.string "time", default: "present", null: false
      t.bigint "topic_id", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "author_id" ], name: "index_facts_on_author_id"
      t.index [ "character_id", "partner_id", "persistent", "topic_id", "month" ], name: "idx_facts_month_lookup"
      t.index [ "character_id" ], name: "index_facts_on_character_id"
      t.index [ "chat_id" ], name: "index_facts_on_chat_id"
      t.index [ "message_id" ], name: "index_facts_on_message_id"
      t.index [ "partner_id" ], name: "index_facts_on_partner_id"
      t.index [ "topic_id" ], name: "index_facts_on_topic_id"
    end

    create_table "instructions", force: :cascade do |t|
      t.boolean "active", default: true, null: false
      t.bigint "character_id"
      t.text "content"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "character_id", "active" ], name: "index_instructions_on_character_id_and_active"
      t.index [ "character_id" ], name: "index_instructions_on_character_id"
    end

    create_table "messages", force: :cascade do |t|
      t.integer "cache_creation_tokens"
      t.integer "cached_tokens"
      t.bigint "character_id"
      t.bigint "chat_id", null: false
      t.text "content"
      t.json "content_raw"
      t.boolean "facts_extracted", default: false, null: false
      t.integer "input_tokens"
      t.boolean "memorize", default: true, null: false
      t.bigint "model_id"
      t.integer "output_tokens"
      t.string "role", null: false
      t.text "thinking_text"
      t.text "thinking_signature"
      t.integer "thinking_tokens"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.bigint "tool_call_id"
      t.index [ "character_id" ], name: "index_messages_on_character_id"
      t.index [ "chat_id" ], name: "index_messages_on_chat_id"
      t.index [ "model_id" ], name: "index_messages_on_model_id"
      t.index [ "role" ], name: "index_messages_on_role"
      t.index [ "tool_call_id" ], name: "index_messages_on_tool_call_id"
    end

    create_table "models", force: :cascade do |t|
      t.string "model_id", null: false
      t.string "name", null: false
      t.string "provider", null: false
      t.string "family"
      t.datetime "model_created_at"
      t.integer "context_window"
      t.integer "max_output_tokens"
      t.date "knowledge_cutoff"
      t.jsonb "modalities", default: {}
      t.jsonb "capabilities", default: []
      t.jsonb "pricing", default: {}
      t.jsonb "metadata", default: {}
      t.boolean "stale", default: false, null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "capabilities" ], name: "index_models_on_capabilities", using: :gin
      t.index [ "family" ], name: "index_models_on_family"
      t.index [ "modalities" ], name: "index_models_on_modalities", using: :gin
      t.index [ "provider", "model_id" ], name: "index_models_on_provider_and_model_id", unique: true
      t.index [ "provider" ], name: "index_models_on_provider"
      t.index [ "stale" ], name: "index_models_on_stale"
    end

    create_table "agents", force: :cascade do |t|
      t.boolean "active", default: true, null: false
      t.boolean "builtin", default: false, null: false
      t.text "instructions"
      t.string "key"
      t.bigint "model_id"
      t.string "name", null: false
      t.float "temperature"
      t.integer "thinking_budget"
      t.string "thinking_effort"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "key" ], name: "index_agents_on_key", unique: true
      t.index [ "model_id" ], name: "index_agents_on_model_id"
    end

    create_table "mcp_servers", force: :cascade do |t|
      t.boolean "active", default: true, null: false
      t.jsonb "config", default: {}, null: false
      t.string "key", null: false
      t.text "last_error"
      t.string "name", null: false
      t.string "transport_type", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "key" ], name: "index_mcp_servers_on_key", unique: true
    end

    create_table "agents_mcp_servers", id: false, force: :cascade do |t|
      t.bigint "agent_id", null: false
      t.bigint "mcp_server_id", null: false
      t.index [ "agent_id", "mcp_server_id" ], name: "index_agents_mcp_servers_on_agent_id_and_mcp_server_id", unique: true
      t.index [ "agent_id" ], name: "index_agents_mcp_servers_on_agent_id"
      t.index [ "mcp_server_id" ], name: "index_agents_mcp_servers_on_mcp_server_id"
    end

    create_table "settings", force: :cascade do |t|
      t.string "key", null: false
      t.string "scope", null: false
      t.string "value"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "scope", "key" ], name: "index_settings_on_scope_and_key", unique: true
    end

    create_table "system_logs", force: :cascade do |t|
      t.datetime "logged_at", null: false
      t.text "message", null: false
      t.jsonb "payload", default: {}, null: false
      t.string "severity", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "logged_at", "id" ], name: "index_system_logs_on_logged_at"
      t.index [ "severity", "logged_at", "id" ], name: "index_system_logs_on_severity_and_logged_at"
    end

    create_table "tool_calls", force: :cascade do |t|
      t.jsonb "arguments", default: {}
      t.bigint "message_id", null: false
      t.string "name", null: false
      t.text "thought_signature"
      t.string "tool_call_id", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "message_id" ], name: "index_tool_calls_on_message_id"
      t.index [ "name" ], name: "index_tool_calls_on_name"
      t.index [ "tool_call_id" ], name: "index_tool_calls_on_tool_call_id", unique: true
    end

    create_table "topics", force: :cascade do |t|
      t.string "name"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end

    add_foreign_key "agents", "models"
    add_foreign_key "agents_mcp_servers", "agents"
    add_foreign_key "agents_mcp_servers", "mcp_servers"
    add_foreign_key "characters", "users", column: "author_id"
    add_foreign_key "chats", "characters"
    add_foreign_key "chats", "characters", column: "partner_id"
    add_foreign_key "chats", "messages", column: "first_visible_message_id", on_delete: :nullify
    add_foreign_key "chats", "messages", column: "last_visible_message_id", on_delete: :nullify
    add_foreign_key "chats", "models"
    add_foreign_key "chats", "users"
    add_foreign_key "fact_aggregates", "characters"
    add_foreign_key "fact_aggregates", "characters", column: "partner_id"
    add_foreign_key "fact_aggregates", "fact_aggregates", column: "parent_id"
    add_foreign_key "fact_aggregates", "topics"
    add_foreign_key "facts", "characters", column: "partner_id"
    add_foreign_key "facts", "chats"
    add_foreign_key "facts", "messages"
    add_foreign_key "facts", "topics"
    add_foreign_key "messages", "chats"
    add_foreign_key "messages", "models"
    add_foreign_key "messages", "tool_calls"
    add_foreign_key "tool_calls", "messages"
    add_foreign_key "users", "characters", column: "main_character_id"
  end
end
