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

## Third-Party Characters & Multi-Subject Facts
- Third-party characters (people, pets, etc.) are created automatically during extraction when first mentioned
- When a statement involves multiple subjects (e.g. "my cat Сима likes playing balls"), extract **separate facts per character** — one for the user ("has a cat named Сима") and one for Сима ("likes playing small soft balls")
- Do NOT use HABTM to link one fact to multiple characters — facts should describe only their actual subject; sharing a fact across characters produces semantically wrong descriptions (e.g. "Anton likes playing small soft balls")

## Running commands

Always use `bash -lc "rvm 3.4.4@ai do <command>"` — e.g. `bash -lc "rvm 3.4.4@ai do bin/rails db:migrate"`.
