# Minimum-Delta Retrofit Recipe

For retrofits, the goal is the **smallest reviewable diff** that makes
the existing codebase Alchemyst-aware. In practice that's almost always
two surfaces: the LLM call site and the system prompt.

This file is the recipe Step 4 + Step 5 follow when computing
`{{RETROFIT_DELTA}}` for the child skill's `IMPLEMENTATION_PLAN.md`.

---

## The two-surface theorem

Across every retrofit archetype (A, B, C, D, E in
[agent-archetypes.md](agent-archetypes.md)), the change set decomposes
into:

1. **Tool / retrieval surface** — somewhere there's an LLM call. Either
   add `search_context` to the tool list, or add an inline
   `context.search` immediately before the LLM call.
2. **System-prompt surface** — somewhere there's a system prompt. Add
   one or two sentences telling the model that the tool / context
   exists and how to use it.

Plus, depending on the archetype:

- **Memory archetype (B)**: a third surface — the message-array
  builder gets `memory.list_turns(...)` prepended; the post-call hook
  gets `memory.add_turn(...)` calls. Two more file edits.
- **Voice archetype (D)**: webhook handler gets `ingest_transcript`;
  pre-call hook gets `pre_call_context`.
- **Personalization archetype (C)**: profile-write site gets a mirror
  to Alchemyst. (Often no edit if the app stores the profile via a
  service — wrap that service.)

Anything beyond these surfaces is **scope creep**. If the plan calls
for refactoring how the LLM call is structured, restructuring file
layout, or introducing a service abstraction "for clarity", the user
is paying for cleanup they didn't ask for. Stop and ask.

---

## Detecting the LLM call site

The scanner (`scripts/scan_agent_signals.sh`) grep's for these
patterns. Each is a **candidate insertion point** for surface 1.

### Anthropic SDK

| Pattern                           | Where the tool list goes                          |
|-----------------------------------|---------------------------------------------------|
| `messages.create(`                | the `tools=[…]` kwarg of this call                |
| `client.messages.create(`         | same                                              |
| `Anthropic(`                      | the file that constructs the client; tools probably defined nearby |

### OpenAI SDK

| Pattern                           | Where the tool list goes                          |
|-----------------------------------|---------------------------------------------------|
| `chat.completions.create(`        | the `tools=[…]` kwarg                             |
| `client.chat.completions.create(` | same                                              |
| `responses.create(`               | new responses API; same `tools=[…]` kwarg         |
| `OpenAI(`                         | the construction site; tools probably defined nearby |

### LangChain / LangGraph / CrewAI / etc.

These wrap the underlying SDK. The retrofit is one level up: add
`search_context` to the agent's tool registry rather than to a raw
SDK call. The scan flags `langchain`, `langgraph`, `crewai`, `dspy`
imports.

### Vercel AI SDK / `ai`

```typescript
generateText({
  model: ...,
  tools: { /* add search_context here */ },
  messages: [...]
})
```

### "Just a script" / no framework

Sometimes the LLM call is a raw `fetch()` to an HTTP endpoint. The
retrofit becomes inline retrieval (Section "Inline retrieval" in
[alchemyst-patterns.md](alchemyst-patterns.md)) — there's no tool
list to extend, so prepend the `context.search` and inline the
results into the prompt.

---

## Detecting the system prompt

The scanner looks for, in order:

1. **Files** matching `*.prompt`, `*.prompt.md`, `system_prompt.*`,
   `prompts/**/*.md`, `prompts/**/*.txt`, `instructions.*`,
   `persona.*`, `CLAUDE.md`, `AGENTS.md`, `.cursorrules`,
   `.windsurfrules`
2. **String literals** assigned to variables named `system_prompt`,
   `SYSTEM_PROMPT`, `systemPrompt`, `instructions`, `system`,
   `INSTRUCTIONS` — these are typically inlined in the same file as
   the LLM call
3. **Heredocs / template literals** with leading `You are…` text

If multiple system prompts exist (e.g. one per agent), the user
picks which to retrofit; the plan lists them all and asks.

---

## The retrofit edit set — output shape

`{{RETROFIT_DELTA}}` in the child skill is a numbered checklist.
Each item is one file edit, with file path, line number (or insertion
point), and a one-line "what to add". Example for archetype A:

```markdown
1. **Add `search_context` tool definition.**
   File: `src/agents/support.ts:42`
   Insertion: inside the `tools: [` array, before the closing bracket.
   Snippet: see `scaffolds/typescript/tool-definition.ts`.

2. **Update system prompt.**
   File: `prompts/system.md:1`
   Insertion: append a single paragraph at the end.
   Snippet:
   > You have access to a `search_context` tool that searches the
   > organisation's internal documents. Use it whenever the answer
   > would benefit from internal context, past tickets, or product
   > documentation. Cite the document you used.

3. **Wire the tool handler.**
   File: `src/agents/support.ts:78`
   Insertion: in the tool-result switch / handler, add a case for
   `name === "search_context"` that calls `client.v1.context.search`.
   Snippet: see `scaffolds/typescript/tool-handler.ts`.

4. **Ingest the corpus** (one-shot, not a code change).
   Run: `npx ts-node scaffolds/typescript/ingest.ts ./docs`
   Verifies: search returns the fixture.
```

The user reviews this checklist, runs the included scripts, and
applies the edits manually (or asks the child skill to apply them
in interactive mode).

---

## Stop conditions

Stop generating retrofit plans and ask the user when any of these
trigger:

- the change set crosses 10 files (Hard Rule 3)
- the LLM call is buried inside a third-party service the user can't
  modify (e.g., a vendor agent platform without a system-prompt slot)
  — Alchemyst can still help via inline retrieval *before* the
  vendor call, but say so explicitly
- the codebase already has Alchemyst wired up (the scan finds
  `@alchemyst-ai/sdk` or `from alchemyst import`) — switch to
  *augmenting* the existing integration rather than retrofitting from
  scratch
- the codebase has a competing context layer (Mem0, Zep, Pinecone)
  and the user hasn't said whether to coexist or replace — ask
  before generating the plan
