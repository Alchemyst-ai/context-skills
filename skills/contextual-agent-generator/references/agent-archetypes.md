# Agent Archetypes — match the user's goal to one of these

Each archetype below has a **decision triggers** section (when to pick
it), a `groupName` shape, the SDK calls it leans on, and the canonical
file scaffold. The Step 5 matcher reads this file and picks **one**
archetype — see Hard Rule 1: never invent a hybrid.

If two archetypes look equally close, present both with a one-line
tradeoff and let the user pick.

---

## A. RAG knowledge base

> "Answer questions using our internal documents."

### Decision triggers

- end goal is Q&A or search over a document corpus
- no requirement to remember individual users across sessions
- one shared knowledge base, possibly tenant-segmented
- examples: support assistant over docs+tickets, code Q&A over a
  repo, internal compliance lookup

### `groupName` shape

```
[domain, category, subcategory]
e.g. ["support", "product-x", "billing"]
e.g. ["engineering", "backend", "auth"]
```

For multi-tenant SaaS: prepend `["org", org_id, ...]`.

### SDK calls

- ingest: `context.add` (or `add_async` if > 1k docs / nightly refresh)
- query: `context.search` with `groupName` + optional `metadata` filter
- update: delete-then-add by `fileName`

### Greenfield scaffold

```
agent/
├── client.{py,ts}        # Alchemyst client init
├── ingest.{py,ts}        # one-shot CLI: read files, chunk, add()
├── search.{py,ts}        # query helper used by the agent loop
├── agent.{py,ts}         # LLM call w/ search_context tool OR inline retrieval
├── .env.example
└── README.md
```

### Retrofit minimum delta

Typically 2 files:

1. add `search_context` tool definition next to existing tool list
2. append a sentence to the system prompt: "You have a `search_context`
   tool. Use it whenever the answer would benefit from internal
   documents."

Plus a one-time `ingest.{py,ts}` script for the corpus.

---

## B. Agent + persistent memory

> "Remember the conversation across sessions."

### Decision triggers

- explicit "remembers me", "picks up where we left off", "knows our
  prior calls"
- per-user or per-session continuity is core
- examples: customer support bot that recalls prior tickets, sales
  co-pilot that recalls prior calls, personal assistant

### `groupName` shape

```
memory:    ["memory", session_id]                    # raw turn-by-turn
profile:   ["user", user_id, "profile"]              # distilled profile
docs:      ["docs", category]                        # any shared knowledge base
```

### SDK calls

- memory write/read: `context.memory.add` / `context.memory.list`
- profile distillation: write summarized profile back to
  `["user", user_id, "profile"]` after N turns
- knowledge base: `context.search` over `["docs", ...]` (same as
  archetype A)

### Greenfield scaffold

```
agent/
├── client.{py,ts}
├── memory.{py,ts}        # add_turn, list_turns, distill_profile
├── search.{py,ts}        # over the docs group (if any)
├── agent.{py,ts}         # combines memory + search + LLM call
├── .env.example
└── README.md
```

### Retrofit minimum delta

3–4 files:

1. wrap the existing LLM call: prepend `memory.list_turns(session_id)`
   to the messages array
2. after the LLM responds, append `memory.add_turn(session_id, "user",
   user_msg)` and `memory.add_turn(session_id, "assistant", reply)`
3. system-prompt sentence: "You have access to prior conversation
   history. Refer to it naturally when relevant."

If the existing app has its own session store, **coexist** — Alchemyst
holds the *retrievable* memory; their store keeps auth/session state.

---

## C. Personalized chat

> "Treat each user differently based on their history and preferences."

### Decision triggers

- the agent's *behaviour* changes per user (tone, what it recommends,
  what it skips)
- preferences exist as structured data somewhere (CRM row, settings
  page)
- examples: B2B newsletter generator, product recommender, coaching
  bot adapting to skill level

### `groupName` shape

```
profile:   ["user", user_id, "profile"]              # the static / slow-moving prefs
behavior:  ["user", user_id, "history"]              # past interactions
shared:    ["catalog", category]                     # what to recommend over
```

### SDK calls

- on user signup / settings change: `context.add` to the profile group
  with a single doc that's the JSON of their preferences
- per request: `context.search` over the profile group (limit 1) +
  separate search over the shared catalog
- compose: pass profile + retrieved catalog items into the system
  prompt

### Greenfield scaffold

```
agent/
├── client.{py,ts}
├── profile.{py,ts}       # upsert_profile, get_profile
├── search.{py,ts}        # over the catalog group
├── agent.{py,ts}         # builds personalised prompt
├── .env.example
└── README.md
```

### Retrofit minimum delta

The retrofit hinges on whether the existing app *already has* a user
profile.

- **Has a profile**: 2 files. (a) on profile change, mirror it to
  Alchemyst; (b) at agent-call time, `search` the profile group and
  inline it into the system prompt.
- **No profile yet**: this is closer to greenfield — generate the full
  profile pipeline.

---

## D. Voice + context flywheel

> "Each call is informed by every prior call with this customer."

### Decision triggers

- product is a voice agent (Vapi, Bland, Retell, ElevenLabs, OpenAI
  Realtime, internal LiveKit)
- transcripts already exist or are about to start being recorded
- continuity across calls is a stated value-add
- examples: outbound sales follow-ups, customer support callback,
  personalised reminder calls

This is the **moat archetype** for Alchemyst — voice + context layered
together is the differentiator. See [how-to.md §Voice Workflows](../../../how-to.md).

### `groupName` shape

```
calls:     ["calls", customer_id, call_id]           # raw transcript
summary:   ["calls", customer_id, "summary"]         # distilled history
profile:   ["customer", customer_id, "profile"]      # CRM-style record
```

### SDK calls

- after each call ends: `context.add` of the transcript under
  `["calls", customer_id, call_id]`
- nightly job: distil the day's calls into a per-customer summary
  (delete-then-add to `["calls", customer_id, "summary"]`)
- on next call: `context.search` over `["calls", customer_id, ...]`
  before the agent speaks; inject as "what we know about this
  customer" in the system prompt

### Greenfield scaffold

```
agent/
├── client.{py,ts}
├── ingest_transcript.{py,ts}   # called from your voice platform's webhook
├── distill.{py,ts}             # nightly summariser
├── pre_call_context.{py,ts}    # called by the voice agent's "before-call" hook
├── .env.example
└── README.md
```

### Retrofit minimum delta

Voice retrofits have a webhook surface and a system-prompt surface.

1. **Webhook**: in the post-call handler, add an `ingest_transcript`
   call.
2. **Pre-call**: in the agent's pre-call hook (or system-prompt
   injection point), call `pre_call_context(customer_id)` and inline
   the result.
3. **System prompt**: add "Here's what we know about this customer
   from prior calls: {context}. Refer to it naturally."

---

## E. Summarization / research agent

> "Synthesize findings from many documents into a report."

### Decision triggers

- output is *long-form* (a report, a brief, a newsletter), not a
  chat reply
- input is a corpus the agent should traverse *deliberately*, not
  just retrieve top-K from
- examples: company research agent, competitive intel, executive
  briefing, B2B newsletter (also see archetype C if it's also
  personalised)

### `groupName` shape

```
sources:   ["research", topic, source_type]          # raw inputs
findings:  ["research", topic, "findings"]           # intermediate notes
reports:   ["research", topic, "reports"]            # final outputs (audit trail)
```

### SDK calls

- ingest: `context.add` per source as the researcher pulls it in
- traverse: multiple `context.search` calls per section (one per
  topic, with different `metadata.section` filters)
- write findings back: `context.add` to `["research", topic,
  "findings"]` so subsequent runs build on prior work
- archive: `context.add` the final report to `reports`

### Greenfield scaffold

```
agent/
├── client.{py,ts}
├── ingest_sources.{py,ts}   # pulls in URLs / docs
├── outline.{py,ts}          # plans the report sections
├── draft.{py,ts}            # per-section draft using context.search
├── compose.{py,ts}          # stitches sections into a final report
├── .env.example
└── README.md
```

### Retrofit minimum delta

Less common as a retrofit — most existing summarization apps are
single-shot LLM calls, and retrofitting context arithmetic into them
crosses Hard Rule 3's 10-file ceiling. If you do retrofit:

1. add `context.search` before each section's prompt
2. archive findings + report after each run
3. system prompt: "Cite each finding with the source from context."

---

## F. Async ingestion pipeline (often combined with A or B)

> "We have a lot of data, refreshed often."

This is a **modifier**, not a standalone archetype. It changes the
ingestion section of A / B / C / D / E from sync to async with polling.

### Decision triggers

- doc count > 10k OR refresh < 1 hour OR both
- ingestion runs on a schedule (cron, queue worker, CI job)

### Changes to scaffold

- `ingest.{py,ts}` becomes batch + `addAsync` + poll loop
- adds `jobs.{py,ts}` with retry / status helpers
- runbook gains a "watch async-job dashboard" step

---

## Decision flowchart

```
Q: Is the output long-form (a report)?       → archetype E (+ F if scale)
Q: Is the product a voice agent?             → archetype D (+ F if scale)
Q: Does the agent's behaviour change per user? → archetype C
Q: Does the agent need to remember across sessions? → archetype B
Q: Otherwise (Q&A over a corpus)?             → archetype A (+ F if scale)
```

If the answer to multiple is yes, **the topmost match wins** — voice
+ context is more specific than RAG, even if RAG is also true.

---

## What does *not* fit any of these

- "I just want a chatbot, no context" — Alchemyst is overkill; tell
  the user.
- "I want to replace OpenAI with Alchemyst" — Alchemyst is a context
  layer, not an LLM. Refer them to [context-api](../../context-api/SKILL.md)
  for the framing.
- "I want a vector DB without `groupName`" — Alchemyst's value comes
  from `groupName`-scoped operations. A flat-namespace vector store
  is a different product (Pinecone, Weaviate). Don't shoehorn.

If the user's request fits none of A–E and isn't covered by F as a
modifier, **stop and tell the user** — Hard Rule 1.
