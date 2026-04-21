class AddInitialSchema < ActiveRecord::Migration[7.0]
  def up
    enable_extension "vector"

    create_table "characters", force: :cascade do |t|
      t.string "name", null: false
      t.text "description", null: false, default: ""
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.boolean "description_up_to_date", default: false, null: false
      t.boolean "ai", default: false, null: false
    end

    create_table "chats", force: :cascade do |t|
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.bigint "model_id"
      t.bigint "user_id"
      t.bigint "partner_id"
      t.text "summary"
      t.boolean "facts_extracted", default: false, null: false
      t.index [ "model_id" ], name: "index_chats_on_model_id"
      t.index [ "partner_id" ], name: "index_chats_on_partner_id"
      t.index [ "user_id" ], name: "index_chats_on_user_id"
    end

    create_table "facts", force: :cascade do |t|
      t.bigint "character_id"
      t.text "content"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.boolean "persistent", default: true, null: false
      t.bigint "author_id"
      t.string "time", default: "present", null: false
      t.date "date_from"
      t.date "date_to"
      t.integer "importance", default: 50
      t.datetime "mentioned_at", precision: nil
      t.bigint "topic_id"
      t.string "kind"
      t.bigint "chat_id"
      t.bigint "message_id"
      t.index [ "author_id" ], name: "index_facts_on_author_id"
      t.index [ "character_id" ], name: "index_facts_on_character_id"
      t.index [ "chat_id" ], name: "index_facts_on_chat_id"
      t.index [ "message_id" ], name: "index_facts_on_message_id"
      t.index [ "topic_id" ], name: "index_facts_on_topic_id"
    end

    create_table "instructions", force: :cascade do |t|
      t.bigint "character_id"
      t.text "content"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "character_id" ], name: "index_instructions_on_character_id"
    end

    create_table "messages", force: :cascade do |t|
      t.string "role", null: false
      t.text "content"
      t.json "content_raw"
      t.text "thinking_text"
      t.text "thinking_signature"
      t.integer "thinking_tokens"
      t.integer "input_tokens"
      t.integer "output_tokens"
      t.integer "cached_tokens"
      t.integer "cache_creation_tokens"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.bigint "chat_id", null: false
      t.bigint "model_id"
      t.bigint "tool_call_id"
      t.bigint "character_id"
      t.boolean "facts_extracted", default: false, null: false
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
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "capabilities" ], name: "index_models_on_capabilities", using: :gin
      t.index [ "family" ], name: "index_models_on_family"
      t.index [ "modalities" ], name: "index_models_on_modalities", using: :gin
      t.index [ "provider", "model_id" ], name: "index_models_on_provider_and_model_id", unique: true
      t.index [ "provider" ], name: "index_models_on_provider"
    end

    create_table "tool_calls", force: :cascade do |t|
      t.string "tool_call_id", null: false
      t.string "name", null: false
      t.text "thought_signature"
      t.jsonb "arguments", default: {}
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.bigint "message_id", null: false
      t.index [ "message_id" ], name: "index_tool_calls_on_message_id"
      t.index [ "name" ], name: "index_tool_calls_on_name"
      t.index [ "tool_call_id" ], name: "index_tool_calls_on_tool_call_id", unique: true
    end

    create_table "topics", force: :cascade do |t|
      t.string "name"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end

    add_foreign_key "chats", "characters", column: "partner_id"
    add_foreign_key "chats", "characters", column: "user_id"
    add_foreign_key "chats", "models"
    add_foreign_key "facts", "chats"
    add_foreign_key "facts", "messages"
    add_foreign_key "facts", "topics"
    add_foreign_key "messages", "chats"
    add_foreign_key "messages", "models"
    add_foreign_key "messages", "tool_calls"
    add_foreign_key "tool_calls", "messages"
  end
end
