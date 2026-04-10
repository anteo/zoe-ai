# Zoe AI — Project Context

Rails 8.0 AI companion app using RubyLLM, PostgreSQL (with vector support), and SolidQueue. The core concept is a conversational AI ("Zoe") that builds up persistent knowledge about people through structured fact extraction.

**Why:** Personalized AI companion that remembers who you are across conversations, not just within a session.

**How to apply:** Frame all architectural suggestions in terms of Rails conventions, ActiveRecord, and background jobs.

## Key directories
- `app/models/` — Fact, Character, Topic, Message, Chat, Instruction
  - `Chat` associations: `belongs_to :user` (Character) and `belongs_to :partner` (Character)
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
- Actor uses `AI::ExtractionFactsAgent.new(chat:).chat` — gets the configured RubyLLM chat session and drives it directly

## Persistent vs Non-Persistent Facts
- **Persistent**: long-term identity traits → feed into character description generation
- **Non-persistent**: specific events → shown in system prompt grouped by temporal period
- Saving a persistent fact sets `character.description_up_to_date = false` → triggers `DescribeCharacter`

## Character Description Generation
- `AI::Actors::DescribeCharacter` (`lib/ai/actors/describe_character.rb`)
- Groups persistent facts into 4 time buckets (>12mo, 12-6mo, 6-3mo, <3mo)
- Summarizes each bucket with LLM (temp 0.1) using `app/prompts/describe_person.erb`
- Joins summaries with time-period headers → stored in `character.description`

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

## Attachments in LLM Messages

`Message#extract_content` appends `(files attached with ID(s): <blob_id> (<filename>), ...)` to the text content whenever a message has attachments, giving the LLM stable IDs to reference in tool calls.

- **User messages**: files ARE sent to LLM; IDs appended to text.
- **Assistant messages (no `content_raw`)**: IDs appended to text only — files are NOT sent to LLM.
- **Assistant messages (`content_raw` present)**: `RubyLLM::Content::Raw` returned unchanged — no modification.
- `with_attachment_ids` owns the `attachments.attached?` guard and returns text unchanged when no attachments, so callers need no extra check.
- IDs are `ActiveStorage::Blob#id` (integer) paired with filename.

## Chat Model ActiveStorage Integration (`app/models/chat.rb`)
- `messages_association` preloads `:attachments_blobs` so RubyLLM can access blobs without N+1 queries
- `persist_content` merges `attachments_to_persist` (deferred attachments) before delegating to super
- `prepare_content_for_storage` forces attachments to a non-nil array so `persist_content` is always called
- `prepare_for_active_storage` splits ActiveStorage hashes (already-persisted blobs) from other attachments before super

## MessagesController (`app/controllers/messages_controller.rb`)
- Accepts attachments via `params.require(:message).permit(:content, attachments: [])`
- Creates `RubyLLM::Content.new(content, attachments)` before `chat.add_message` — attachments are raw uploaded files at this point, saved by RubyLLM's ActiveRecord hooks

## Third-Party Characters & Multi-Subject Facts
- Third-party characters (people, pets, etc.) are created automatically during extraction when first mentioned
- When a statement involves multiple subjects (e.g. "my cat Сима likes playing balls"), extract **separate facts per character** — one for the user ("has a cat named Сима") and one for Сима ("likes playing small soft balls")
- Do NOT use HABTM to link one fact to multiple characters — facts should describe only their actual subject; sharing a fact across characters produces semantically wrong descriptions (e.g. "Anton likes playing small soft balls")

## Message Actions (Edit, Delete, Resend)

### Routes & Controller Pattern
- Routes: `resources :messages, only: [:create, :update, :destroy]` with member `post :resend`
- `update`: Replace message content → destroy all later messages → re-render chat from DB
- `destroy`: Remove message → Turbo remove from DOM
- `resend`: Destroy all later messages → re-render chat from DB (re-runs AI response)
- Authorization: Check `message.user?` for edit/resend; delete available for all
- Finding message: `Message.joins(:chat).where(id:, chats: { user: @current_user }).first` ensures permission

### View & Interaction Pattern
- **Component structure**: Outer `<div id="message-<id>" class="group" data-controller="message">` wraps both content bubble and attachments so `group-hover` works uniformly
- **Action icons**: Rendered in message header on hover (`opacity-0 group-hover:opacity-100`)
  - **User messages**: Edit + resend buttons appear **before** the sender name (left side of header)
  - **Assistant messages**: Only delete button appears **after** the timestamp (right side of header)
  - Delete available for all message types
- **Header styling**: `chat-header` has `mb-1` for vertical spacing between header and content bubble
- **Inline edit form**: Hidden by default, toggled via Stimulus; replaces bubble with textarea + Cancel/Save buttons
- **Stimulus controller**: `startEdit`/`cancelEdit` toggle targets; focus cursor at end of textarea; Turbo replaces whole message post-save so form disappears naturally

### Turbo Streams for Message Edit/Resend
When a message is edited or resent, destroy all later messages in the DB, then re-render the **entire chat container** from the database state. This is simpler and more maintainable than trying to track and remove individual message stream elements:
```ruby
message.chat.messages.where("id > ?", message.id).destroy_all
render turbo_stream: turbo_stream.replace("chat-messages", ChatComponent.new(chat: message.chat, current_user:))
```
Then `RespondJob` broadcasts the new AI response into the live container via Action Cable as usual. **Do NOT use a helper that returns a stream array** — always re-render the whole container to ensure the DOM matches the DB state.

### DaisyUI CSS Grid Constraint
**Critical**: `chat-bubble` elements **must be direct children of `.chat`** for DaisyUI's CSS Grid positioning to work. Extra wrapper divs (e.g., `data-message-target="view"` wrappers) will break the grid layout. Put `data-*` attributes **directly on the `chat-bubble` element**, not on parents wrapping it.

## Internationalization (i18n)

Rails i18n is configured with multiple locale files in `config/locales/`:
- **`en.yml`** — English (default locale)
- **`ru.yml`** — Russian

All user-facing strings (UI labels, buttons, confirmation messages) must use `t(...)` helper in views/components. Translation keys follow naming conventions:
- **`label_*`** — UI button/form labels (e.g., `label_edit`, `label_send`, `label_delete`)
- **`placeholder_*`** — Input placeholder text (e.g., `placeholder_dialog_input`)
- **`confirm_*`** — Confirmation/dialog messages (e.g., `confirm_delete_message`)
- **`text_*`** — Static text blocks, often HTML (e.g., `text_greeting_html`)

In components/views, use `<%= t(:key_name) %>` or `<%= t("key_name") %>`. In JavaScript/Stimulus, call the server or use inline data attributes with i18n values.

Each locale file must have the same keys to ensure consistency across languages. Always add keys to **both** `en.yml` and `ru.yml` when introducing new UI text.

## Running commands

Always use `bash -lc "rvm 3.4.4@ai do <command>"` — e.g. `bash -lc "rvm 3.4.4@ai do bin/rails db:migrate"`.

## Rails form_with Conventions for Inline Edits

When implementing inline edit forms (especially in Stimulus-controlled views):
- **Always use `form_with model: record`** rather than `form_with url:, method:` for persisted records
- This approach automatically:
  1. Scopes form fields correctly (e.g., `message[content]` instead of bare `content`)
  2. Uses the correct HTTP method (PATCH for updates on persisted records)
  3. Routes to the proper REST endpoint
  4. **Pre-populates textarea/input values from the model** — critical for inline editing so users see current content
- Without `model:`, you must manually pass `value:` to each field and handle method routing yourself, and the form can't auto-populate values from the model
- Example: `<%= form_with model: message do |f| %>` → fields auto-named `message[content]`, method defaults to PATCH if `message.persisted?`

## ViewComponent Partials and Method Access

When breaking a ViewComponent template into partials, **partials do not have access to component methods** (only to locals passed explicitly).

**Pattern**: Compute values in the component class or main template, then pass as local variables (prefer boolean flags over method calls):
- ✓ **Good**: `render "message_component/header", message:, is_current_user: is_current_user?, sender:`
  - Compute `is_current_user?` once in the main template (component method available)
  - Pass as a plain boolean local `is_current_user:` (not a method reference)
  - Partial uses `<% if is_current_user %>` without calling a method
- ✗ **Bad**: `render "message_component/header", message:` then in partial calling `<% if is_current_user? %>` (method doesn't exist in partial context)

This pattern applies when refactoring fat components: compute expensive/permission checks in the main template, then use simple locals in partials to keep them pure and readable. Reduces coupling and makes partial reuse easier.

## ActiveRecord dup and Primary Keys

**Gotcha**: When using `record.dup` on a persisted record, ActiveRecord **intentionally omits the primary key**, so the duplicated object has `id = nil`. This breaks view logic that relies on stable IDs for DOM selectors.

**Example**: If you do `display_message = message.dup` and then render the template with `id="message-#{display_message.id}"`, the view will have no ID attribute (not `id="message-nil"`). When you later need a Turbo Stream `remove` operation targeting that element, `turbo_stream.remove("message-#{message.id}")` will target a different ID than the DOM element has.

**Solution**: When duplicating a record for display, explicitly copy the ID if you need stable selectors:
```ruby
display_message = message.dup
display_message.id = message.id  # Restore the DB record's ID so view selectors match
```

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

**In job perform method**: Always check `execution&.cancelled?` early to allow cancelling running jobs:
```ruby
def perform(...)
  return if execution&.cancelled?
  # ... rest of job logic
end
```

This allows `StopTypingJob` to cancel both currently-running and queued `TypeSentenceJob` instances, preventing messages from continuing to type after the user clicks stop.

**Example**: `TypeSentenceJob` checks `execution.cancelled?` and returns early if true, which stops broadcasting sentences. Scheduled follow-on `TypeSentenceJob` instances are discarded by `TypeSentenceJob.cancel(chat)`.
