# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_27_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agents", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "builtin", default: false, null: false
    t.datetime "created_at", null: false
    t.text "instructions"
    t.string "key", null: false
    t.bigint "model_id"
    t.string "name", null: false
    t.float "temperature"
    t.integer "thinking_budget"
    t.string "thinking_effort"
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_agents_on_key", unique: true
    t.index ["model_id"], name: "index_agents_on_model_id"
  end

  create_table "agents_mcp_servers", id: false, force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.bigint "mcp_server_id", null: false
    t.index ["agent_id", "mcp_server_id"], name: "index_agents_mcp_servers_on_agent_id_and_mcp_server_id", unique: true
    t.index ["agent_id"], name: "index_agents_mcp_servers_on_agent_id"
    t.index ["mcp_server_id"], name: "index_agents_mcp_servers_on_mcp_server_id"
  end

  create_table "characters", force: :cascade do |t|
    t.boolean "ai", default: false, null: false
    t.datetime "created_at", null: false
    t.text "description", default: "", null: false
    t.boolean "description_up_to_date", default: false, null: false
    t.boolean "is_default", default: false, null: false
    t.string "name", limit: 50, null: false
    t.boolean "third_party", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["is_default"], name: "index_characters_on_is_default"
    t.index ["is_default"], name: "index_characters_on_single_default_ai", unique: true, where: "((ai = true) AND (is_default = true))"
  end

  create_table "characters_users", id: false, force: :cascade do |t|
    t.bigint "character_id", null: false
    t.bigint "user_id", null: false
    t.index ["character_id", "user_id"], name: "index_characters_users_on_character_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_characters_users_on_user_id"
  end

  create_table "chats", force: :cascade do |t|
    t.bigint "character_id"
    t.boolean "closed", default: false, null: false
    t.datetime "created_at", null: false
    t.boolean "facts_extracted", default: false, null: false
    t.boolean "memorize", default: true, null: false
    t.bigint "model_id"
    t.bigint "partner_id"
    t.text "summary"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["character_id"], name: "index_chats_on_character_id"
    t.index ["model_id"], name: "index_chats_on_model_id"
    t.index ["partner_id"], name: "index_chats_on_partner_id"
    t.index ["user_id"], name: "index_chats_on_user_id"
  end

  create_table "fact_aggregates", force: :cascade do |t|
    t.date "anchor_month"
    t.text "body", default: "", null: false
    t.bigint "character_id", null: false
    t.datetime "created_at", null: false
    t.integer "facts_count", default: 0, null: false
    t.string "kind", null: false
    t.bigint "parent_id"
    t.string "slot_key", null: false
    t.datetime "source_updated_at"
    t.boolean "stale", default: false, null: false
    t.text "summary"
    t.datetime "summary_source_updated_at"
    t.string "summary_status", default: "pending", null: false
    t.bigint "topic_id", null: false
    t.datetime "updated_at", null: false
    t.index ["character_id", "kind", "anchor_month"], name: "idx_fact_aggregates_band_lookup"
    t.index ["character_id"], name: "index_fact_aggregates_on_character_id"
    t.index ["parent_id"], name: "index_fact_aggregates_on_parent_id"
    t.index ["slot_key"], name: "idx_fact_aggregates_unique_slot", unique: true
    t.index ["summary_status"], name: "index_fact_aggregates_on_summary_status"
    t.index ["topic_id"], name: "index_fact_aggregates_on_topic_id"
  end

  create_table "facts", force: :cascade do |t|
    t.bigint "author_id"
    t.bigint "character_id"
    t.bigint "chat_id"
    t.text "content"
    t.datetime "created_at", null: false
    t.date "date_from"
    t.date "date_to"
    t.integer "importance", default: 50
    t.string "kind"
    t.datetime "mentioned_at", precision: nil
    t.bigint "message_id"
    t.date "month"
    t.boolean "persistent", default: true, null: false
    t.string "time", default: "present", null: false
    t.bigint "topic_id"
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_facts_on_author_id"
    t.index ["character_id", "persistent", "topic_id", "month"], name: "idx_facts_month_lookup"
    t.index ["character_id"], name: "index_facts_on_character_id"
    t.index ["chat_id"], name: "index_facts_on_chat_id"
    t.index ["message_id"], name: "index_facts_on_message_id"
    t.index ["topic_id"], name: "index_facts_on_topic_id"
  end

  create_table "facts_bak", id: :bigint, default: -> { "nextval('facts_id_seq'::regclass)" }, force: :cascade do |t|
    t.bigint "author_id"
    t.bigint "character_id"
    t.bigint "chat_id"
    t.text "content"
    t.datetime "created_at", null: false
    t.date "date_from"
    t.date "date_to"
    t.integer "importance", default: 50
    t.string "kind"
    t.datetime "mentioned_at", precision: nil
    t.bigint "message_id"
    t.boolean "persistent", default: true, null: false
    t.string "time", default: "present", null: false
    t.bigint "topic_id"
    t.datetime "updated_at", null: false
  end

  create_table "instructions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "character_id"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["character_id", "active"], name: "index_instructions_on_character_id_and_active"
    t.index ["character_id"], name: "index_instructions_on_character_id"
  end

  create_table "mcp_servers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.jsonb "config", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.string "transport_type", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_mcp_servers_on_key", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.integer "cache_creation_tokens"
    t.integer "cached_tokens"
    t.bigint "character_id"
    t.bigint "chat_id", null: false
    t.text "content"
    t.json "content_raw"
    t.datetime "created_at", null: false
    t.boolean "facts_extracted", default: false, null: false
    t.integer "input_tokens"
    t.boolean "memorize", default: true, null: false
    t.bigint "model_id"
    t.integer "output_tokens"
    t.string "role", null: false
    t.text "thinking_signature"
    t.text "thinking_text"
    t.integer "thinking_tokens"
    t.bigint "tool_call_id"
    t.datetime "updated_at", null: false
    t.index ["character_id"], name: "index_messages_on_character_id"
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["model_id"], name: "index_messages_on_model_id"
    t.index ["role"], name: "index_messages_on_role"
    t.index ["tool_call_id"], name: "index_messages_on_tool_call_id"
  end

  create_table "models", force: :cascade do |t|
    t.jsonb "capabilities", default: []
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.date "knowledge_cutoff"
    t.integer "max_output_tokens"
    t.jsonb "metadata", default: {}
    t.jsonb "modalities", default: {}
    t.datetime "model_created_at"
    t.string "model_id", null: false
    t.string "name", null: false
    t.jsonb "pricing", default: {}
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["capabilities"], name: "index_models_on_capabilities", using: :gin
    t.index ["family"], name: "index_models_on_family"
    t.index ["modalities"], name: "index_models_on_modalities", using: :gin
    t.index ["provider", "model_id"], name: "index_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_models_on_provider"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.boolean "cancelled", default: false
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "tool_calls", force: :cascade do |t|
    t.jsonb "arguments", default: {}
    t.datetime "created_at", null: false
    t.bigint "message_id", null: false
    t.string "name", null: false
    t.text "thought_signature"
    t.string "tool_call_id", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_tool_calls_on_message_id"
    t.index ["name"], name: "index_tool_calls_on_name"
    t.index ["tool_call_id"], name: "index_tool_calls_on_tool_call_id", unique: true
  end

  create_table "topics", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
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
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["main_character_id"], name: "index_users_on_main_character_id"
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "((provider IS NOT NULL) AND (uid IS NOT NULL))"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agents", "models"
  add_foreign_key "agents_mcp_servers", "agents"
  add_foreign_key "agents_mcp_servers", "mcp_servers"
  add_foreign_key "chats", "characters"
  add_foreign_key "chats", "characters", column: "partner_id"
  add_foreign_key "chats", "models"
  add_foreign_key "chats", "users"
  add_foreign_key "fact_aggregates", "characters"
  add_foreign_key "fact_aggregates", "fact_aggregates", column: "parent_id"
  add_foreign_key "fact_aggregates", "topics"
  add_foreign_key "facts", "chats"
  add_foreign_key "facts", "messages"
  add_foreign_key "facts", "topics"
  add_foreign_key "facts_bak", "chats"
  add_foreign_key "facts_bak", "messages"
  add_foreign_key "facts_bak", "topics"
  add_foreign_key "messages", "chats"
  add_foreign_key "messages", "models"
  add_foreign_key "messages", "tool_calls"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "tool_calls", "messages"
  add_foreign_key "users", "characters", column: "main_character_id"
end
