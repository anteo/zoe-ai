# Zoe AI — Project Context

Rails 8.0 AI companion app using RubyLLM, PostgreSQL (with vector support), and SolidQueue. The core concept is a conversational AI ("Zoe") that builds up persistent knowledge about people through structured fact extraction.

**Why:** Personalized AI companion that remembers who you are across conversations, not just within a session.

**How to apply:** Frame all architectural suggestions in terms of Rails conventions, ActiveRecord, and background jobs.

## Key Directories
- `app/models/` — Core chat/memory entities (`Chat`, `Message`, `Fact`, `FactAggregate`, `Character`, `Topic`, `User`) plus runtime/config models (`Instruction`, `Model`, `Agent`, `ToolCall`, `MCPServer`, `Setting`)
- `lib/ai/actors/` — Extraction, aggregation, and summarization orchestration (`ExtractFacts`, `AggregatePersistentFacts`, `SummarizeFactAggregate`, `DescribeCharacter`, `SummarizeChat`, etc.)
- `lib/ai/` — BaseAgent subclasses (e.g. `AI::Agents::ExtractFacts`)
- `lib/ai/tools/` — Tool integrations used by agents (character image ops, event search, etc.)
- `app/prompts/ai/agents/` — ERB templates for AI agent prompts
- `app/views/ai/actors/` — Actor rendering templates (e.g. character description formats)
- `app/jobs/` — Async orchestration (`RespondJob`, `ExtractFactsJob`, `AggregatePersistentFactsJob`, `SummarizeFactAggregateJob`, `CloseChatJob`, `SummarizeChatJob`, etc.)

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

**FactAggregate** — hierarchical summaries of persistent facts by `character` + `topic`:
- Month rows (`kind: month`) and rolling period bands (`m0_3`, `m3_6`, `m6_12`, `m12_24`, `year_YYYY`)
- `summary_status` lifecycle: pending | in_progress | done | failed
- Parent/child links used to build band summaries from month summaries
- `slot_key` as stable unique identity per character/topic/kind/anchor month

**Message** — `has_many_attached :attachments` (ActiveStorage). `content_raw` stores raw provider response for assistant message replay. Visibility includes attachment-only messages (no text).

**Model / Agent / MCPServer / ToolCall / Setting** — runtime AI infrastructure:
- `Model`: provider model registry used for chat resolution
- `Agent`: configurable agent profiles (model + thinking effort + MCP bindings)
- `MCPServer`: external tool server definitions and lifecycle
- `ToolCall`: persisted LLM tool invocation records
- `Setting`: app/AI/provider/mail/UI configuration tree

## Top-Level Flows

### 1) Live chat response flow
1. User message is persisted to `messages`.
2. `RespondJob` resolves and pins the chat model (if missing), then runs `AI::Agents::Zoe`.
3. Assistant message is streamed/typed (`TypeSentenceJob`) and then fact extraction is scheduled (`ExtractFactsJob`).

### 2) Facts extraction flow
1. `ExtractFactsJob` runs per-chat with `limits_concurrency` (single extractor per chat, conflicts discarded).
2. `AI::Actors::ExtractFacts` replays visible messages in order into `AI::Agents::ExtractFacts`.
3. If a message has `memorize: false`, it is still sent to extraction context but paired with empty facts (`[]`), so continuity remains while skipping storage.
4. Extracted rows become `facts` records (subject `character`, `author`, `topic`, temporal fields, importance, source message/chat).
5. Third-party characters can be auto-created on demand when mentioned.

### 3) Persistent memory aggregation flow
1. Fact changes mark related month aggregates stale (`Fact` callback → `FactAggregate.mark_months_stale!`).
2. `AggregatePersistentFactsJob` rebuilds monthly rows and rolling time-band rows (`m0_3`, `m3_6`, `m6_12`, `m12_24`, `year_YYYY`) per character/topic.
3. `SummarizeFactAggregateJob` summarizes month rows first, then parent bands when all children are ready.
4. `RetryFailedFactAggregatesJob` re-enqueues failed month/band summaries.
5. Character descriptions are derived from `fact_aggregates` (prefer summaries, fallback to aggregate body), not raw facts.

### 4) Chat lifecycle flow
1. `CloseStaleChatsJob` finds stale open chats and enqueues `CloseChatJob`.
2. `CloseChatJob` removes empty chats or marks non-empty chats as `closed` and broadcasts close event.
3. `SummarizeChatJob` asynchronously generates chat summaries for closed chats.

## Running Commands

Always use `bash -lc "rvm 3.4.4@ai do <command>"` — e.g. `bash -lc "rvm 3.4.4@ai do bin/rails db:migrate"` to run Rake/Rails/Ruby commands.

Do not run asset build commands in development (e.g. `npm run build`, `bun bun.config.js`, or equivalent JS/CSS build tasks). Assume a dev watcher/process handles assets.

## Checks & Validation

After implementation is done, skip running checks/validations (tests, linters, formatters, static checks). The user runs all validation steps manually.

## Internationalization (i18n)

Rails i18n with `config/locales/en.yml` and `ru.yml`. Always add keys to **both** files.
Keep lines sorted alphabetically.

Key conventions: `label_*` (buttons/forms), `placeholder_*` (inputs), `confirm_*` (dialogs), `text_*` (static text/HTML).

## Commit Workflow

When user asks to commit, analyze current git changes, group by feature, show proposed commit plan first, then commit after user approval.
Prefer atomic commits: each commit should contain one logical change only (single concern), even if that results in more commits.
Before starting any commit sequence, unstage everything first (`git restore --staged .`) and then stage files explicitly per planned commit.
Run git commands sequentially; do not run git commands in parallel.
