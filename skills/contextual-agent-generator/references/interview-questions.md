# Interview Questions

The meta-skill walks the user through these questions before scanning
the repo. Their answers shape the matched archetype, the `groupName`
schema, the SDK choice, and the implementation plan.

The questions marked with **★** are the minimum set. In **hands-off**
mode (Step 0), ask only the starred questions in one batch and infer
the rest from the scan. In **interactive** mode, ask one at a time and
confirm the running summary at Q4 and Q8.

---

## 1. End goal **★**

> "In one sentence, what is this agent supposed to *do* for the user
> or organization?"

Examples to suggest if the user is stuck:

- "answer support questions using our internal docs and past tickets"
- "summarise a candidate's GitHub activity for an interviewer"
- "act as a sales co-pilot that knows every prior call with the customer"
- "generate a personalised B2B newsletter from the user's preferences
  and recent industry news"
- "triage incoming bug reports by routing them to the right team"

**Why this matters:** the end goal is the dominant signal for archetype
matching. Q&A over docs → RAG knowledge base; "remembers prior calls"
→ agent + memory; "personalised" → personalization archetype.

**Map answers to:** `{{END_GOAL}}` and the first column of
`agent-archetypes.md`.

---

## 2. Capabilities **★**

> "List the things the agent must be able to do. Not how — just what.
> Use bullets."

Probe for these if the user is terse:

- search org documents
- remember the user across sessions
- personalise to the individual
- call external tools / APIs
- summarise across many docs
- ingest new data continuously
- enforce off-limits topics
- cite sources in its answers

**Why this matters:** capabilities → SDK calls. "Remember across
sessions" requires the memory endpoints. "Cite sources" requires
metadata to be carried through. "Continuous ingestion" pushes the plan
toward async ingestion.

**Map answers to:** `{{CAPABILITIES_LIST}}` and the SDK call set in
`IMPLEMENTATION_PLAN.md`.

---

## 3. Data sources **★**

> "What feeds the agent? Files? A database? Live API pulls? Past
> conversation transcripts? User-uploaded content?"

For each source ask:

- **Format**: PDF / Markdown / DOCX / JSON / CSV / DB rows / raw text
- **Volume**: rough doc count + size (under 1k? 10k? 100k?)
- **Refresh**: one-time / weekly / hourly / streaming
- **Authority**: who owns it; can the agent cite from it directly?

**Why this matters:** drives ingestion strategy (sync vs async),
metadata schema, and `groupName` design. A 500-doc one-shot upload is
a different shape than a 100k-doc nightly refresh.

**Map answers to:** `{{DATA_SOURCES}}` and the ingestion section of
`IMPLEMENTATION_PLAN.md`.

---

## 4. Users / boundaries **★**

> "Who talks to this agent — end users, internal staff, both? And
> what are the boundaries between them — per user, per organisation,
> per session, per product?"

Probe for these if it's unclear:

- "Should user A's data ever surface in user B's results?" (per-user)
- "Do you have multiple tenants / customers on one deployment?" (per-org)
- "Should the agent remember the conversation across sessions?"
  (per-session vs per-user)
- "Is there a 'shared knowledge base' all users see?" (org-wide layer)

**Why this matters:** this is the dominant signal for `groupName`
design. A `groupName` that's too flat leaks data across boundaries; one
that's too nested fragments retrieval.

**Map answers to:** `{{GROUP_NAME_SCHEMA}}` in `ARCHITECTURE.md`. See
[alchemyst-patterns.md §groupName design](alchemyst-patterns.md) for
the canonical shapes.

---

## 5. Scale & freshness

> "Roughly how many documents will the agent search over? How fresh
> do they need to be — minutes, hours, days?"

Defaults to apply if the user doesn't know:

- under 1k docs, low refresh → sync ingestion, no async needed
- 1k–10k docs, daily refresh → sync at first, plan for async later
- > 10k docs OR sub-hour refresh → async ingestion from day one

**Why this matters:** drives `{{INGESTION_MODE}}`. Picking async
prematurely adds polling and job-management code the user doesn't need;
picking sync at scale gets the user rate-limited.

**Map answers to:** `{{INGESTION_MODE}}` and the bulk-ingestion section
of `IMPLEMENTATION_PLAN.md`.

---

## 6. Existing app vs greenfield **★**

> "Are we starting fresh, or adding Alchemyst to a codebase you already
> have? If the latter, point me at the repo."

For an existing repo, also ask:

- "Where does the LLM call happen today?" (file path, if they know)
- "Where does the system prompt live?" (file or string literal)
- "Anything else doing context retrieval already — Pinecone, Weaviate,
  a memory library?" → drives the *coexist vs replace* decision

**Why this matters:** decides `{{MODE}}`. Retrofits are minimum-delta
plans; greenfield gets a full scaffold tree.

**Map answers to:** `{{MODE}}` and either `{{RETROFIT_DELTA}}` or
`{{GREENFIELD_TREE}}`.

---

## 7. Surrounding stack

> "What LLM provider — Anthropic, OpenAI, both? What language /
> framework is the rest of the app in? Where does it deploy?"

For greenfield, also ask:

- preferred web framework (FastAPI / Express / Next / none / "just a script")
- deploy target (Vercel / Fly / Render / their own k8s / local-only)

For retrofit, infer from the scan and only ask if the scan is
ambiguous (e.g., a polyglot repo).

**Why this matters:** drives the imports, the example tool-call shape
(Anthropic-style messages vs OpenAI-style chat completions), and the
deploy notes in `RUNBOOK.md`.

**Map answers to:** `{{LLM_PROVIDER}}` and the imports / framework
section of the scaffold.

---

## 8. Off-limits

> "Anything the agent must refuse, redact, or escalate? PII? Competitor
> mentions? Regulated advice? Internal-only documents that should never
> reach external users?"

**Why this matters:** these turn into clauses in the system prompt of
the scaffold and into metadata filters on `search_context` calls (e.g.,
`metadata: { visibility: "external" }` for an external-facing agent).

**Map answers to:** `{{OFF_LIMITS}}` (system-prompt clauses) and
metadata-filter notes in `ARCHITECTURE.md`.

---

## Wrap-up

After the interview, summarise back what you heard in 4–6 bullet
points ("you want an agent that…") and ask the user to confirm or
correct before generating the skill. People often realise they
over-specified or under-specified mid-summary.

In **hands-off** mode, also list the things you assumed (e.g., "I
assumed sync ingestion because doc count is under 1k") so the user
can override before Step 5.
