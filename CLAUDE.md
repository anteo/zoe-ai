# Zoe AI — Project Context

Rails 8.0 AI companion app using RubyLLM, PostgreSQL (with vector support), and SolidQueue. The core concept is a conversational AI ("Zoe") that builds up persistent knowledge about people through structured fact extraction.

**Why:** Personalized AI companion that remembers who you are across conversations, not just within a session.

**How to apply:** Frame all architectural suggestions in terms of Rails conventions, ActiveRecord, and background jobs.

## Persistent memory

Use Mem0 for durable project memory in this repository.

Rules:
1. Always set `app_id="ai"` in Mem0 operations for this project.
2. At task start, call `search_memories` to load relevant context.
3. After meaningful progress, review session's conversation, if discovered anything worth preserving for future sessions, call `add_memory` for durable engineering context.
   - High-level architectural decisions and WHY they were made
   - Domain model relationships and key concepts
   - Data flow between major components (one-liner per pipeline)
   - Project-specific conventions not derivable from code
   - How to run commands or environment setup
4. Avoid commit-style change summaries in memory (they are already available in git history and usually have low future retrieval value).
5. Keep memories specific and searchable (include feature names, file paths, and concrete outcomes).
6. Before ending a long task/session, store a short session-state summary with next steps.

## Key Directories
- `app/models/` — Fact, Character, Topic, Message, Chat, Instruction, User
- `lib/ai/actors/` — ExtractFacts, DescribeCharacter, SummarizeLines, ObjectifyChat
- `lib/ai/` — BaseAgent subclasses (e.g. `ExtractionFactsAgent`)
- `lib/ai/tools/` — Memory (topic_search + last_chat_search via embeddings)
- `app/prompts/` — ERB templates for all LLM system prompts
- `app/jobs/` — ExtractFactsJob, CloseChatsJob, SummarizeChatJob, etc.

## Domain Model

**User** — authentication/profile (email, first_name, last_name). `has_and_belongs_to_many :characters`. Has `main_character` (preferred character).

**Character** — the conversational entity (name, ai flag, description, instructions). Participates in chats. Third-party characters (people, pets) are created automatically during fact extraction when first mentioned.

**Chat** — two-way conversation; `belongs_to :character` (user) and `belongs_to :partner` (AI). Has `closed` flag (set at midnight), `summary` (generated async after closure).

**Fact** — structured knowledge extracted from conversations:
- `character_id` (subject), `author_id` (who mentioned it), `content` (3rd person text)
- `persistent` (bool) — persistent = identity traits; non-persistent = time-bound events
- `kind` — attribute | experience | belief | preference | plan
- `importance` (0-100) — facts <20 discarded at extraction
- `time` — past | present | future; `date_from`, `date_to` for event ranges
- `topic_id` — FK to topics (flat, name-only, created dynamically)
- `chat_id`, `message_id` — source tracking

**Message** — `has_many_attached :attachments` (ActiveStorage). `content_raw` stores raw provider response for assistant message replay. Visibility includes attachment-only messages (no text).

## RubyLLM Chat Session Persistence Pattern

Two ways to use an agent with a Chat:
- **`.new(chat:).chat`** — persists messages to the DB (visible in UI)
- **`.chat(chat:)`** (class method) — in-memory session, no persistence (for extraction, summarization, internal reasoning)

## Extraction Pipeline

1. `ExtractFactsJob` triggers after each message (background, concurrency-limited per chat)
2. `AI::Actors::ExtractFacts` orchestrates: instantiates `ExtractionFactsAgent`, processes messages sequentially
3. Returns schema-enforced `{ "facts": [...] }` JSON; `build_fact()` creates records
4. Multi-subject statements → separate facts per character (no HABTM on facts)

**Memory mode toggle** (`memorize` boolean on Message): When `false`, message is added to LLM context with empty facts response (`[]`) for continuity, but extraction is skipped. AI messages auto-inherit from the last user message. User can toggle via brain icon in chat input; state is stored as a **module-scoped JS variable** in `ChatInputController` — persists across Turbo navigations (state stays off while chatting), but resets to `true` on page refresh/reopen. No cookie persistence; lives only in browser memory for the session.

## Character Description Generation

- Triggered when a persistent fact is saved (`character.description_up_to_date = false`)
- Groups persistent facts into 4 time buckets (>12mo, 12-6mo, 6-3mo, <3mo), sub-grouped by topic
- **One LLM call per time period** (not per topic) — O(periods) calls instead of O(periods × topics)
- LLM produces `<topic name="...">` XML sections; code wraps in `<period from="..." to="...">` tags
- Stored as nested XML, injected into system prompt for all subsequent chats

## System Prompt Structure

Uses XML tags for hard semantic boundaries between sections:
- `<context>` — date, conversation partner, last conversation time
- `<identity role="assistant">` / `<identity role="user">` — character descriptions (prevents identity bleed)
- `<known_people>` → `<person name="...">` — other known characters
- `<events>` — non-persistent facts grouped by temporal period
- `<yesterday_conversation>` — yesterday's chat summaries (injected directly, not via tool)
- `<instructions>` — AI-specific instructions

**System prompt caching:** `BaseAgent#apply_instructions` snapshots the rendered prompt into the `messages` table as a system message on the **first agent invocation** for a chat (via `RespondJob` → `find` with `persist: false`), using RubyLLM's `with_instructions` + `persist_system_instruction`. On subsequent requests, `apply_instructions` returns early if a persistent system message exists (checks `chat.messages_association.where(role: :system).exists?`), avoiding re-render. This means `to_llm` loads the frozen system message from DB, LLM sees identical bytes every turn → consistent cache hits. No explicit `sync_instructions!` call needed; the snapshot happens transparently. Semantic model: mid-conversation extractions (ExtractFactsJob, DescribeCharacterJob) affect the *next* chat's prompt only.

## Key Design Decisions

**Markdown rendering in messages** — Server-side via `redcarpet` gem in `ApplicationHelper#markdown`. Instantiates new renderer on each call (thread-safe). Supports fenced code, tables, strikethrough, autolink, hard line breaks. Links open in new tab (`rel=noopener`). Applied in `message_component.html.erb` for all message content.

**Yesterday's summaries in system prompt** (not via tool): Tools are opt-in; LLM won't reliably call recall. Direct injection ensures automatic conversational continuity. Older conversations use the Memory tool.

**LLM context pollution prevention**: System-injected annotations (e.g. attachment blob IDs) are added at LLM read time (`extract_content`) but stripped before DB persistence (`prepare_content_for_storage`). Prevents LLM from learning to reproduce system annotations.

**Daily chat closure**: `CloseChatsJob` runs at midnight, sets `closed: true`, broadcasts redirect immediately. Summarization runs async via `SummarizeChatJob` to keep the critical path short. Startup initializer catches stale chats from restarts.

**Image generation**: `AI.paint` wraps RubyLLM with `with:` parameter for image-to-image (OpenRouter provider only). Characters have `has_many_attached :images` with `metadata[:description]` for selection.

**Actor error handling**: Use `fail_on RubyLLM::Error` in actors for graceful degradation in jobs — returns failed Result instead of raising.

## Running Commands

Always use `bash -lc "rvm 3.4.4@ai do <command>"` — e.g. `bash -lc "rvm 3.4.4@ai do bin/rails db:migrate"`.

## Internationalization (i18n)

Rails i18n with `config/locales/en.yml` and `ru.yml`. Always add keys to **both** files.

Key conventions: `label_*` (buttons/forms), `placeholder_*` (inputs), `confirm_*` (dialogs), `text_*` (static text/HTML).
