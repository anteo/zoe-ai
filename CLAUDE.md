# Zoe AI — Project Context

Rails 8.0 AI companion app using RubyLLM, PostgreSQL (with vector support), and SolidQueue. The core concept is a conversational AI ("Zoe") that builds up persistent knowledge about people through structured fact extraction.

**Why:** Personalized AI companion that remembers who you are across conversations, not just within a session.

**How to apply:** Frame all architectural suggestions in terms of Rails conventions, ActiveRecord, and background jobs.

## Key directories
- `app/models/` — Fact, Character, Topic, Message, Chat, Instruction, User
  - `User` — profile info only (email, first_name, last_name); `has_many :characters`
  - `Character` — the actual conversational entity; `belongs_to :user` (optional); acts as participant in chats
  - `Chat` — two-way conversation; `belongs_to :character` and `belongs_to :partner` (both Characters)
- `lib/ai/actors/` — ExtractFacts, DescribeCharacter, SummarizeLines, ObjectifyChat
- `lib/ai/` — BaseAgent subclasses: `ExtractionFactsAgent` (facts extraction LLM wrapper)
- `lib/ai/tools/` — Memory (topic_search + last_chat_search via embeddings)
- `app/prompts/` — ERB templates for all LLM system prompts
- `app/jobs/` — ExtractFactsJob (background, concurrency-limited per chat)

## Facts Table Schema
- `character_id` — who the fact is about
- `author_id` — who mentioned it
- `content` — fact text (3rd person)
- `persistent` (bool, default true) — persistent = identity-defining; non-persistent = time-bound events
- `kind` — "attribute" | "experience" | "belief" | "preference" | "plan"
- `importance` (0-100, default 50) — facts <20 are discarded at extraction time
- `time` — "past" | "present" | "future"
- `date_from`, `date_to` — event date range
- `mentioned_at` — when fact was mentioned in conversation
- `topic_id` — FK to topics table (flat, name-only categorization)
- `chat_id`, `message_id` — source tracking

## Extraction Pipeline
1. `ExtractFactsJob` (background, concurrency-limited per chat) triggers after each message
2. `AI::Actors::ExtractFacts` (`lib/ai/actors/extract_facts.rb`) — orchestrates the loop
3. Actor instantiates `AI::ExtractionFactsAgent.new(chat:)` and calls `.chat` on it to get the configured RubyLLM session (`llm_chat`)
4. Processes messages sequentially; already-extracted messages become context via `add_message`
5. Returns `{ "facts": [...] }` JSON (schema-enforced); `build_fact()` creates ActiveRecord records
6. Prompt: `app/prompts/ai/extraction_facts_agent/instructions.txt.erb`

## ExtractionFactsAgent (`lib/ai/extraction_facts_agent.rb`)
- Inherits from `AI::BaseAgent`
- `inputs :chat` — the Rails `Chat` record being processed
- `temperature 0.1`
- `instructions topics: -> { Topic.all }` — renders prompt with topics
- Schema defined inline via `ruby_llm-schema` DSL: wraps result in `{ facts: [...] }`; each fact has typed fields with enums/ranges
- **`initialize(chat:, **kwargs)`** is required: `chat:` conflicts with `RubyLLM::Agent`'s own `chat:` kwarg (pre-built session), so must route via `super(inputs: { chat: }, **kwargs)`
- **RubyLLM Chat Session Persistence Pattern**:
  - `.new(chat:).chat` — Creates an instance, then accesses the configured RubyLLM session (binds to the ActiveRecord `Chat`, dumping messages into the `messages` table)
  - `.chat(chat:)` — Class-level method (if defined on the agent class) builds an in-memory RubyLLM chat session **without persisting** to the messages table
  - Use `.chat(chat:)` for one-off LLM operations that shouldn't leave a trace in the conversation history (e.g., internal reasoning, summarization, fact extraction)
  - Use `.new(chat:).chat` when you want messages to persist in `Chat#messages` and be visible in the UI

## Persistent vs Non-Persistent Facts
- **Persistent**: long-term identity traits → feed into character description generation
- **Non-persistent**: specific events → shown in system prompt grouped by temporal period
- Saving a persistent fact sets `character.description_up_to_date = false` → triggers `DescribeCharacter`

## Character Description Generation
- Triggered when a persistent fact is saved (sets `character.description_up_to_date = false`)
- `AI::Actors::DescribeCharacter` (`lib/ai/actors/describe_character.rb`)
- Groups persistent facts into 4 time buckets (>12mo, 12-6mo, 6-3mo, <3mo)
- Summarizes each bucket with LLM (temp 0.1) using `app/prompts/describe_person.erb`
- Joins summaries with time-period headers → stored in `character.description`
- Description is used in system prompt for all subsequent chats with this character

## SummarizationAgent Pattern
- `AI::SummarizationAgent` (`lib/ai/agents/summarization_agent.rb`) — `BaseAgent` subclass, temp 0.1, takes `chat` input
- Used by `AI::Actors::SummarizeChat` to generate conversation summaries (replaces old chunking/grouping approach)
- Prompt: `app/prompts/ai/summarization_agent/instructions.txt.erb`
- Part of the daily chat closure workflow: when `CloseChatsJob` runs at midnight, it summarizes each unclosed chat before setting `closed: true`
- Summary is stored in `chat.summary` and broadcast to subscribed clients via `ChatChannel`
- **Single-pass approach**: Unlike `SummarizeLines` (which chunks lines and summarizes per chunk), `SummarizationAgent` takes the full conversation text and summarizes in one pass. This works because single chats are always bounded (~1 day), so grouping by date adds no value.
- Messages are formatted as `to_direct_speech` (already a convention) and joined with newlines before being sent to the agent

## System Prompt Structure (`app/prompts/ai/zoe/instructions.txt.erb`)
1. Partner (AI) character description
2. User character description
3. Other known characters
4. Non-persistent facts grouped by temporal period (`time_facts.txt.erb`)
5. AI-specific instructions from `instructions` table
6. Current date/time + last conversation timestamp

## Memory Tool (`lib/ai/tools/memory.rb`)
- `topic_search(query, name, detailed)` — semantic search via embeddings
- `last_chat_search(name, detailed)` — retrieve last conversation with a person
- Both use PostgreSQL vector extension

## Topics
- Flat table, name only, created dynamically during extraction
- One topic per fact (optional)

## Message Model (`app/models/message.rb`)
- `has_many_attached :attachments` — ActiveStorage attachments on messages
- `content_raw` (JSON) — stores raw provider response for assistant messages; used by `RubyLLM::Content::Raw` to bypass provider formatting on replay
- `extract_content` is overridden to route by role **before** checking `content_raw`; RubyLLM's `acts_as_message` super checks `content_raw` first regardless of role, which is wrong for user messages
- For user messages, `super` downloads ActiveStorage attachments to tempfiles and returns a `RubyLLM::Content` object
- `RubyLLM::Content.new(text, attachments_array)` accepts an array of existing `RubyLLM::Attachment` objects as its second argument (no re-download needed)
- **Visibility rule**: `visible` scope must include messages with empty `content` if they have ActiveStorage attachments. Uses subquery: `"content != '' OR id IN (SELECT DISTINCT record_id FROM active_storage_attachments WHERE record_type = 'Message')"`
  - This allows users to send files alone without text, and prevents invisible attachment-only messages in chat history
  - The `visible?` instance method has a corresponding check: `(user? || assistant?) && (content.present? || attachments.attached?)`

## LLM Context Pollution & Content Sanitization Pattern

**Anti-pattern**: System-injected annotations should never appear in message text that the LLM sees as its own prior output, because the LLM learns to reproduce the format.

**Solution**: Use a two-stage approach:
1. **At LLM read time** (`extract_content`): Inject system annotations so the LLM has the context it needs
2. **At DB write time** (`prepare_content_for_storage`): Strip system annotations before persistence

This ensures annotations are always available to the LLM but never accumulate in the database.

**Applied here**: `Message#extract_content` appends `(files attached: [...])` suffix with blob IDs so the LLM can reference attachments in tool calls. `Chat#prepare_content_for_storage` strips this suffix before saving so the LLM never sees it as part of its own prior output.

## Chat Model ActiveStorage Integration (`app/models/chat.rb`)
- `messages_association` preloads `:attachments_blobs` so RubyLLM can access blobs without N+1 queries
- `persist_content` merges `attachments_to_persist` (deferred attachments) before delegating to super
- `prepare_content_for_storage` forces attachments to a non-nil array so `persist_content` is always called
- `prepare_for_active_storage` splits ActiveStorage hashes (already-persisted blobs) from other attachments before super
- `closed` (boolean, default false) — set to true when chat is closed at midnight by `CloseChatsJob`; checked by controller before rendering chat; used to prevent users from sending messages to old chats

## MessagesController (`app/controllers/messages_controller.rb`)
- Accepts attachments via `params.require(:message).permit(:content, attachments: [])`
- Creates `RubyLLM::Content.new(content, attachments)` before `chat.add_message` — attachments are raw uploaded files at this point, saved by RubyLLM's ActiveRecord hooks

## Third-Party Characters & Multi-Subject Facts
- Third-party characters (people, pets, etc.) are created automatically during extraction when first mentioned
- When a statement involves multiple subjects (e.g. "my cat Сима likes playing balls"), extract **separate facts per character** — one for the user ("has a cat named Сима") and one for Сима ("likes playing small soft balls")
- Do NOT use HABTM to link one fact to multiple characters — facts should describe only their actual subject; sharing a fact across characters produces semantically wrong descriptions

## Message Actions (Edit, Delete, Resend)

- Routes: `resources :messages, only: [:create, :update, :destroy]` with member `post :resend`
- `update`: Replace message content → destroy all later messages → re-render chat from DB
- `destroy`: Remove message → Turbo remove from DOM
- `resend`: Destroy all later messages → re-render chat from DB (re-runs AI response)
- Authorization: Check `message.user?` for edit/resend; delete available for all
- Finding message: `Message.joins(:chat).where(id:, chats: { character: @current_character }).first` ensures permission
- When editing/resending: re-render the **entire chat container** from DB state (not individual stream elements), then `RespondJob` broadcasts the new AI response via Action Cable

## Internationalization (i18n)

Rails i18n with `config/locales/en.yml` and `ru.yml`. Always add keys to **both** files.

Translation key conventions:
- **`label_*`** — UI button/form labels
- **`placeholder_*`** — Input placeholder text
- **`confirm_*`** — Confirmation/dialog messages
- **`text_*`** — Static text blocks, often HTML

## Running commands

Always use `bash -lc "rvm 3.4.4@ai do <command>"` — e.g. `bash -lc "rvm 3.4.4@ai do bin/rails db:migrate"`.

## Job Cancellation with SolidQueue

The `MissionControl` concern provides a pattern for canceling jobs across all execution states:

**Key states in SolidQueue:**
- `SolidQueue::ClaimedExecution` — currently running
- `SolidQueue::ScheduledExecution` — scheduled for future run
- `SolidQueue::ReadyExecution` — ready but not yet claimed
- `SolidQueue::BlockedExecution` — blocked (e.g., due to concurrency limits)

**Cancellation pattern** (`MissionControl#cancel`):
1. For **running** jobs: set `execution.cancelled = true` (stops mid-execution via early return check)
2. For **scheduled/ready/blocked** jobs: call `execution.job.discard` (removes from queue entirely)

**In job perform method**: Always check `execution&.cancelled?` early:
```ruby
def perform(...)
  return if execution&.cancelled?
  # ... rest of job logic
end
```

## Actor Error Handling Pattern with `fail_on`

RubyLLM Actors support `fail_on` to catch specific exceptions and convert them to failed results (instead of raising):

```ruby
class SummarizeChat < Actor
  input :chat, type: Chat
  fail_on RubyLLM::Error
  
  def call
    # If RubyLLM::Error is raised, service_actor catches it and returns 
    # a failed Result object instead
  end
end
```

**Job context**: When calling an actor from a job and you need graceful degradation:
```ruby
result = AI::Actors::SummarizeChat.call(chat:)
unless result.success?
  Rails.logger.error "Failed to summarize chat ##{chat.id}: #{result.error}"
end
# Always proceed with next step (close the chat, broadcast, etc.)
chat.update!(closed: true)
ChatChannel.broadcast_to(chat, type: "closed")
```

This pattern allows jobs to handle actor failures without crashing, while still logging the error for debugging.

## Dynamic Tool Parameters in RubyLLM

The `params do ... end` block is evaluated as a proc each time the schema is serialized, so DB queries inside it always reflect current state — no `params_schema` override needed:

```ruby
params do
  characters = ::Character.all.map { |c| "#{c.id} (#{c.name})" }.join(", ")

  string :character_id,
         description: "ID of the character. Available: #{characters}",
         enum: ::Character.pluck(:id).map(&:to_s),
         required: true
end
```

Use `enum` + `description` together: enum enforces constraints, description gives the LLM human-readable context.

## Image Generation (`AI.paint`)

`AI.paint` wraps RubyLLM's image generation with an added `with:` parameter for image-to-image:

- **Text-to-image** (`with:` omitted): delegates directly to `RubyLLM::Image.paint`
- **Image-to-image** (`with: [blob, ...]`): only supported via the custom `AI::Providers::OpenRouter` subclass (`lib/ai/providers/open_router.rb`), which overrides `paint` to pass source images as content in the request payload

When `with:` is present and the resolved provider is not `AI::Providers::OpenRouter`, it raises an error. Other providers can be patched by subclassing their RubyLLM provider and overriding `paint` similarly.

## Daily Chat Closure Pattern

Chats are closed at midnight via a scheduled job, not dynamically based on date boundaries:

**Closure mechanism** (`CloseChatsJob`, triggered at midnight via `config/recurring.yml`):
1. Finds all unclosed chats from previous days: `Chat.where(closed: false).where("created_at < ?", Date.current.beginning_of_day)`
2. For each chat:
   - Sets `closed: true` on the chat
   - Broadcasts `type: "closed"` via `ChatChannel` immediately (subscribers receive the message and redirect to `/`)
   - **If chat has no summary**: enqueues `SummarizeChatJob.perform_later(chat)` for async background processing
3. On app startup, `config/initializers/close_stale_chats.rb` checks for any stale unclosed chats and enqueues the job if needed (handles app restarts at non-midnight times)

**Pattern rationale**: Closure and broadcast happen synchronously to unblock the user immediately. Summarization runs async in the background to avoid blocking the closure job. This prevents summarization latency from delaying the UI redirect.

**Controller check**: `@chat.closed?` replaces the old `@chat.from_previous_day?`. Redirect if closed in controller before showing chat.

**Why this approach**: Server-side closure with broadcast ensures all connected clients receive the redirect signal immediately, even if they have the chat open in a browser tab. Avoids race conditions and client-side clock skew. Decoupling summarization from closure keeps the critical path short.

## Session & Current Character Model

**Session lifecycle**:
- Session stores `session[:character_id]` (the ID of the authenticated Character record)
- Controllers set `@current_character` via `set_current_character` before_action:
  ```ruby
    @current_character = characters.find_by(id: session[:character_id]) ||
                         current_user.main_character ||
                         characters.order(:name).first
  ```
- Falls back to `current_user.main_character` (explicitly set preferred character), then to first available character if session character_id is nil (for testing/dev)

**Why User model exists**:
- Decouples authentication/profile (User) from conversation identity (Character)
- User has `email`, `first_name`, `last_name` — used for Gravatar and identification
- Character has `name`, `ai`, `description`, `instructions` — the conversational entity
- One User → many Characters via HABTM (`has_and_belongs_to_many :characters`)

**User-Character Relationship (HABTM)**:
- Changed from one-to-many (`Character.belongs_to :user`) to many-to-many (`User.has_and_belongs_to_many :characters`)
- Enables future scenarios where Characters can be shared/accessed by multiple Users
- Join table: `characters_users` (created by migration)
- Migration also added `main_character_id` to Users table: the user's currently active/preferred character
- `User.belongs_to :main_character, class_name: "Character", optional: true` — tracks which character the user prefers
- When a user switches characters, update `session[:character_id]`; `main_character_id` is optional (for dev/testing where a user might have no characters)

## Recent Chat Summaries in System Prompt

**Design decision**: Inject recent chat summaries directly into the system prompt (not via tool) to ensure **automatic** conversational continuity without requiring explicit LLM decision-making.

**Rationale**:
- Tools are opt-in; the LLM won't call `recall_previous_chat` unless conversation context triggers it, making continuity unreliable
- System prompt injection ensures Zoe always has narrative context from recent conversations available
- Summaries bridge the gap between atomic facts (decontextualized) and conversational continuity (narrative)
- Prompt size impact is manageable: 3 chats × 200-500 tokens per summary = ~1500 tokens max

**What to inject**:
- Yesterday's closed + summarized chats (always include)
- Today's earlier chats are already surfaced via `time_facts` (extracted facts), so skip unsummarized same-day chats to avoid duplication
- Cap at last 3 days or last 5 summaries for a hard bound

**Implementation pattern**:
```ruby
# character.rb
def recent_chat_summaries(partner:, limit: 5)
  Chat.where(character: self, partner: partner, closed: true)
      .where.not(summary: [nil, ""])
      .where("created_at > ?", 3.days.ago)
      .order(created_at: :desc)
      .limit(limit)
      .reverse  # chronological order
end
```

Insert into `app/prompts/ai/zoe/instructions.txt.erb` between "Events and facts" and "Your instructions":
```erb
<% if (summaries = chat.character.recent_chat_summaries(partner: chat.partner)).present? %>
# Recent conversations

<% summaries.each do |past_chat| %>
## <%= I18n.l(past_chat.created_at.to_date, locale: :en) %>
<%= past_chat.summary %>

<% end %>
<% end %>
```

**Use existing Memory tool for**: Explicit recall of older conversations beyond the 3-day window ("what did we talk about last week?")
