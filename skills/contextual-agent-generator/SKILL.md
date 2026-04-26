---
name: contextual-agent-generator
description: >
  Interview the user about an AI-agent project they want to build (or
  retrofit) on the Alchemyst context platform, then generate a child skill
  that plans and scaffolds the implementation end-to-end. The child skill
  carries the matched Alchemyst pattern (RAG, agent + persistent memory,
  personalization, voice + context flywheel, async ingestion at scale,
  etc.), the SDK choice (Python or TypeScript), the `groupName` design,
  the LLM-call wiring, and — for *existing* repos — the *minimum delta*
  needed to make the codebase Alchemyst-aware (typically: add a
  `search_context` tool call and tweak the system prompt). For a single
  repo named "Project 1" this produces
  `contextual-agent-generator--project-1`; for a monorepo with nested
  projects it produces one skill per project, double-hyphen-joined for
  nesting (`contextual-agent-generator--project-2--project-3` for
  `project-2/project-3`). Use whenever the user asks to: (1) build a
  context-aware AI agent on Alchemyst, (2) add Alchemyst / the Context
  Layer / `search_context` to an existing app, (3) plan an agent that
  needs persistent memory or per-user personalization, (4) wire RAG over
  organizational data into an LLM call, (5) scaffold an agent project
  from scratch with Alchemyst SDK, (6) retrofit a chatbot or voice agent
  with context arithmetic, (7) generate the implementation plan / file
  tree / starter code for an Alchemyst-backed agent, (8) compare which
  Alchemyst pattern fits their use case. Trigger phrases include
  "context-aware agent", "Alchemyst agent", "build an agent on Alchemyst",
  "add the context layer to my app", "scaffold a RAG agent", "agent with
  memory", "personalized agent", "wire `search_context` into my LLM call",
  "make this repo Alchemyst-compatible", "retrofit my chatbot with
  context", "minimum changes to use Alchemyst", and any mention of
  building or planning an agent that needs context, memory, or
  retrieval against organizational data.
---

# contextual-agent-generator — Meta Skill

Generate a **child agent-implementation skill per project** that plans
and scaffolds a context-aware AI agent on the [Alchemyst](https://getalchemystai.com)
platform — matching the user's stated goals and capabilities to a known
Alchemyst pattern, choosing an SDK, designing the `groupName` hierarchy,
producing starter code, and (for existing repos) computing the minimum
delta needed to make the codebase Alchemyst-aware.

This is a **meta skill**: its output is another skill you install and
use to actually do the implementation. For background on the meta-skill
pattern, see [how-to.md §Core Concept: Meta Skills vs Direct Skills](../../how-to.md).

For Alchemyst SDK specifics consumed by the generated child, see also
the sibling [context-api](../context-api/SKILL.md) skill — it covers
context arithmetic, `groupName`, and the SDK surface. This skill plans
*projects*; `context-api` documents the *primitive*.

## Why a per-project agent skill

A generic "build me an agent on Alchemyst" answer either over-specifies
(picking an SDK, a `groupName` shape, and a pattern the user didn't ask
for) or under-specifies (handing back a list of endpoints with no plan).
A project-scoped child skill can do better because it carries:

- the **matched archetype** (RAG, agent + memory, personalized chat,
  voice + context flywheel, summarization agent, async-ingestion
  pipeline) so the plan is shaped by a known-good pattern, not assembled
  from scratch every invocation;
- the **SDK and language decision**, made once during the interview /
  scan, so the scaffolds are concrete and runnable rather than
  pseudocode in two languages;
- the **`groupName` hierarchy** (e.g. `["org", "user", session]` vs
  `["product", "tenant", "module"]`), designed up-front to match the
  data the agent will see, rather than chosen ad-hoc per call site;
- for **existing repos**, the *exact* set of files to touch and the
  *exact* tool-call / system-prompt edits — the goal is a small,
  reviewable diff, not a rewrite.

The interview in Step 1 is what populates these — skipping it gives a
generic plan that is barely better than copy-pasting the SDK README.

## Output — what gets created

For every project (or every greenfield target) a skill is written to:

```
.agents/skills/contextual-agent-generator--<slug>/
  SKILL.md                # how the child skill drives the implementation
  README.md               # human-facing quick start
  CAPABILITIES.md         # what the agent will be able to do (interview Q1–Q3)
  ARCHITECTURE.md         # matched archetype, groupName design, data flow
  IMPLEMENTATION_PLAN.md  # ordered, file-level plan (greenfield) or minimum-delta plan (retrofit)
  RUNBOOK.md              # how to verify the agent works end-to-end
  scaffolds/              # starter code in the chosen SDK only (python/ OR typescript/)
    <files>               # client init, ingest, search, memory, agent loop, .env.example
  examples/
    matched-archetype.md  # the canonical example for the matched pattern
  custom/                 # user edits placed here survive regeneration
.claude/skills/contextual-agent-generator--<slug>  -> ../../.agents/skills/...  (symlink)
```

### Naming

The generated skill is named `contextual-agent-generator--<chain>`
where `<chain>` is the double-hyphen-joined slug of the project's path
from the monorepo root.

| Input                                          | Generated skill name                                                          |
|------------------------------------------------|-------------------------------------------------------------------------------|
| single repo `my-app`                           | `contextual-agent-generator--my-app`                                          |
| monorepo with `project-1`, `project-2`         | `contextual-agent-generator--project-1`, `contextual-agent-generator--project-2` |
| nested `project-2/project-3`                   | `contextual-agent-generator--project-2--project-3`                            |
| greenfield (user-supplied project name)        | `contextual-agent-generator--<user-slug>`                                     |

The wrapper/monorepo root is **not** part of the slug chain. Only the
directory name of the project itself (and any intermediate project
ancestors) appears. Slugification: lowercase, spaces/underscores/dots →
hyphens, strip other non-alphanumerics, collapse repeat hyphens.

## Hard rules

These exist so a generated skill can never silently mis-shape the
agent, leak credentials, or make a retrofit larger than it needs to be.

1. **Match a documented pattern, never invent one.** The architecture
   in `ARCHITECTURE.md` must point back to one of the archetypes in
   [references/agent-archetypes.md](references/agent-archetypes.md). If
   none of them fits, say so and stop — don't fabricate a hybrid that
   the user can't validate against the docs.
2. **One SDK per child skill.** Pick Python *or* TypeScript and scaffold
   in that language only. Mixed-language scaffolds confuse the user and
   double the surface area for bugs. Selection rule:
   - **Existing repo**: `tsconfig.json` present at any project root →
     TypeScript; otherwise Python. If the project clearly uses neither
     (e.g. Go-only repo with an LLM call site), ask the user.
   - **Greenfield**: ask the user; default Python if they have no
     preference.
3. **Minimum delta for retrofits.** When the input is an existing repo
   with an LLM call site, the plan is to *add a tool* and *edit the
   system prompt*, not to refactor the call site. The plan must list
   the exact files to touch and the exact lines (or insertion points)
   where edits land. If the change set exceeds 10 files, stop and warn —
   the user almost certainly wants a smaller scope first.
4. **Never read or echo secret files.** Skip every `.env`, `.env.*`
   (except `.env.example` / `.env.sample` / `.env.template`), `*.key`,
   `*.pem`, `credentials.*`. The scaffolds always include a
   `.env.example` with `ALCHEMYST_AI_API_KEY=` placeholder — never a
   real key, never a real value pulled from the user's machine.
5. **`groupName` is designed, not guessed.** Every child skill carries
   an explicit `groupName` schema in `ARCHITECTURE.md` (e.g.
   `["org:{org_id}", "user:{user_id}", "session:{session_id}"]`) with
   a one-line rationale per layer. A `groupName` without a rationale
   is a leaky abstraction the next dev will misuse.
6. **Greenfield scaffolds run.** The starter code under `scaffolds/`
   must run on a clean machine with a single API key set — no missing
   imports, no TODO holes in the wiring. If a piece is intentionally
   left for the user (e.g. their own DB connection), it's clearly
   marked `# TODO(user):` with a one-line description.
7. **Never modify the source project during generation.** All output
   goes under `.agents/skills/` and `.claude/skills/`. The retrofit
   plan *describes* the edits but does not apply them — the user (or
   the child skill, on a separate explicit invocation) applies them.
8. **Surface the autonomy choice.** Before doing anything heavy
   (Step 5 onward), ask the user which mode they want — see
   [references/autonomy-modes.md](references/autonomy-modes.md). Don't
   assume hands-off, and don't pepper the user with questions in
   hands-off mode.

## Workflow

### Step 0 — Pick an autonomy mode

Before the interview, ask the user one question:

> "I can run this end-to-end with one batch of questions up front
> (hands-off), or check in with you between steps for course correction
> (interactive). Which do you prefer?"

Defaults if the user shrugs:

- **interactive** for retrofits — the cost of a wrong assumption inside
  someone's codebase is high
- **hands-off** for greenfield — there's no production code to break,
  and the user can edit the output

Record the choice; thread it into the generated child skill's
`SKILL.md` so the same mode applies when the child runs.

See [references/autonomy-modes.md](references/autonomy-modes.md) for
how each mode behaves at every step.

### Step 1 — Interview the user

Read [references/interview-questions.md](references/interview-questions.md)
and walk the user through it. The questions cover:

1. **End goal** — what does the agent *do* for the user / org?
2. **Capabilities** — list of things the agent must be able to do
   (search docs, remember conversations, personalize per user, run
   tools, summarize, etc.).
3. **Data sources** — what feeds the agent? (file uploads, database
   tables, transcripts from prior calls, API pulls, manual upserts.)
4. **Users / boundaries** — who does the agent talk to, and where do
   user / tenant / session boundaries live? This drives `groupName`.
5. **Scale & freshness** — how many docs, how often updated, what's
   the staleness tolerance? Drives async vs sync ingestion.
6. **Existing app vs greenfield** — point at a repo, or describe what
   to scaffold.
7. **Surrounding stack** — LLM provider (Anthropic, OpenAI, both),
   web framework, deploy target. Drives scaffold imports.
8. **Off-limits** — anything the agent must refuse, redact, or escalate.

In **hands-off** mode, ask Q1–Q4 + Q6 in one batch, infer the rest
from the scan or sensible defaults, and tell the user what was assumed
in the final report.

In **interactive** mode, ask one question at a time and confirm the
running summary at Q4 and Q8.

### Step 2 — Identify target(s)

Accept any of:

- an absolute or relative path
- a GitHub URL (`git clone --depth 1 <url> /tmp/contextual-agent-target-$$`)
- "this repo" / "current project" → current working directory
- an explicit list of paths (run the workflow per path independently)
- **greenfield**: a project name + chosen output directory; the workflow
  treats it as a single project rooted at that directory

```bash
TARGET_DIR="<user-provided-path-or-cwd-or-greenfield-output-dir>"
```

### Step 3 — Detect project topology

```bash
bash <skill_path>/scripts/detect_projects.sh "$TARGET_DIR"
```

Output is TSV, one line per project:

```
<abs_path>\t<slug-chain>\t<lang>\t<framework>
```

`<slug-chain>` is already formatted for use after
`contextual-agent-generator--`. The script handles workspace manifests
(`pnpm-workspace.yaml`, `turbo.json`, `nx.json`, `lerna.json`,
`rush.json`, `package.json` with `workspaces`, Cargo `[workspace]`,
`go.work`), the standard project manifests, nested projects (as
double-hyphen chains), and a zero-manifest fallback (treat target as
one project named after its directory basename).

If detection finds zero projects (no manifests anywhere) and the user
asked for a retrofit, stop and ask whether they meant greenfield. If
they confirm greenfield, treat the target dir as one project.

### Step 4 — Scan for agent / SDK signals (retrofit only)

Skip this step for greenfield.

For each project row from Step 3:

```bash
bash <skill_path>/scripts/scan_agent_signals.sh "<abs_path>"
```

The scan surfaces:

- **LLM call sites** — `anthropic`, `openai`, `messages.create`,
  `chat.completions`, `generate*`, `Anthropic(`, `OpenAI(` — the
  retrofit's tool-call insertion points
- **system prompts / agent prompts** — `*.prompt`, `*.prompt.md`,
  `system_prompt.*`, `prompts/**`, `agents/**`, `CLAUDE.md`,
  `AGENTS.md`, `.cursorrules`, `.windsurfrules`, `instructions.*` —
  where the "you have access to a `search_context` tool" sentence will
  go
- **language signal** — `tsconfig.json` anywhere → TypeScript;
  otherwise Python (Rule 2 above)
- **existing context / RAG** — vector DB clients (`pinecone`, `weaviate`,
  `chroma`, `qdrant`, `pgvector`), memory libraries (`mem0`, `zep`),
  basic embedding calls. The plan must explicitly say whether to *replace*
  or *coexist* — defaulting to coexist unless the user asked otherwise
- **auth / tenant boundaries** — `userId`, `tenantId`, `orgId`,
  `sessionId` patterns in models or middleware. These seed the
  `groupName` design
- **secrets layout** — where existing API keys live (`.env`, AWS Secrets
  Manager, Vault). The plan reuses the same pattern for
  `ALCHEMYST_AI_API_KEY`, never invents a new one

Use the scan output, plus the interview answers, to populate the child
skill's `ARCHITECTURE.md`, `IMPLEMENTATION_PLAN.md`, and
`CAPABILITIES.md`.

### Step 5 — Match an Alchemyst archetype

Read [references/agent-archetypes.md](references/agent-archetypes.md) and
pick exactly one archetype that fits the interview answers. Each
archetype carries:

- a one-paragraph description
- the canonical `groupName` shape
- the SDK calls that wire it up (ingest, search, memory)
- the file scaffold for greenfield
- the typical retrofit edit set

If two archetypes look equally close, present both to the user with a
one-line tradeoff and let them pick. Don't blend — Hard Rule 1.

The archetype determines what gets templated into the child skill in
the next step.

### Step 6 — Generate the child skill from templates

Use the templates under `<skill_path>/templates/child-skill/`. Every
`.tmpl` file is rendered with these placeholders:

| Placeholder              | Source                                                      |
|--------------------------|-------------------------------------------------------------|
| `{{SKILL_SUFFIX}}`       | the slug-chain from Step 3                                  |
| `{{PROJECT_NAME}}`       | human-readable project name (basename of project dir)       |
| `{{PROJECT_PATH}}`       | absolute path to the project (or greenfield output dir)     |
| `{{DATE}}`               | `date -u +%Y-%m-%d`                                         |
| `{{MODE}}`               | `greenfield` or `retrofit`                                  |
| `{{AUTONOMY}}`           | `hands-off` or `interactive` (Step 0)                       |
| `{{ARCHETYPE}}`          | matched archetype name (Step 5)                             |
| `{{ARCHETYPE_RATIONALE}}`| one paragraph: why this archetype fits the interview answers |
| `{{SDK}}`                | `python` or `typescript` (Rule 2)                           |
| `{{LLM_PROVIDER}}`       | `anthropic`, `openai`, or `both` (interview Q7)             |
| `{{END_GOAL}}`           | one-line summary of what the agent does (interview Q1)      |
| `{{CAPABILITIES_LIST}}`  | bullet list (interview Q2)                                  |
| `{{DATA_SOURCES}}`       | bullet list (interview Q3)                                  |
| `{{GROUP_NAME_SCHEMA}}`  | the rationale-annotated `groupName` schema (interview Q4 + scan) |
| `{{INGESTION_MODE}}`     | `sync`, `async`, or `mixed` (interview Q5)                  |
| `{{OFF_LIMITS}}`         | bullet list (interview Q8) — wired into the system prompt   |
| `{{RETROFIT_DELTA}}`     | the file-level edit list (retrofit only — Step 4 + 5)       |
| `{{GREENFIELD_TREE}}`    | the file tree the scaffolds will produce (greenfield only)  |
| `{{RUNBOOK_STEPS}}`      | the verification recipe for the matched archetype           |

Render each template by straightforward text substitution — there's no
need for a templating engine. Substitute placeholders and write the
file. Some templates also contain `{{#if KEY=="VALUE"}}…{{/if}}`
blocks; emit the inner content only when the condition holds, drop
the block otherwise (and never emit the literal `{{#if}}` / `{{/if}}`
markers).

Only emit the scaffold subtree for the chosen `{{SDK}}` — copy
`templates/child-skill/scaffolds/python/` *or*
`templates/child-skill/scaffolds/typescript/` into the child skill's
`scaffolds/` dir, then render any `.tmpl` files inside.

The generated `IMPLEMENTATION_PLAN.md` always carries the universal
verification checks from
[references/alchemyst-patterns.md §verification](references/alchemyst-patterns.md)
(API key reachable, `groupName` round-trips a fixture, end-to-end
search returns the fixture) plus archetype-specific steps.

### Step 7 — Install & symlink

```bash
SKILL_NAME="contextual-agent-generator--${SLUG_CHAIN}"
mkdir -p ".agents/skills/${SKILL_NAME}" .claude/skills
# (file writes from Step 6 land inside .agents/skills/${SKILL_NAME}/)
ln -sfn "../../.agents/skills/${SKILL_NAME}" ".claude/skills/${SKILL_NAME}"
ls ".claude/skills/${SKILL_NAME}/SKILL.md"   # verify
```

### Step 8 — Report

For each project, tell the user:

1. Skill name (`contextual-agent-generator--<slug-chain>`) and absolute
   path
2. Mode (`greenfield` / `retrofit`) and SDK (`python` / `typescript`),
   with a one-line "why this SDK" if it was auto-chosen
3. Matched archetype + the one-line rationale
4. `groupName` schema with rationale per layer
5. For retrofits: the file-level delta as a numbered checklist
   (e.g., "1. add `search_context` tool definition to `src/agent.ts:42`;
   2. append context-tool sentence to `prompts/system.md:1`")
6. For greenfield: the file tree the scaffold will produce on disk
7. How to invoke the child next time, e.g.:
   > "Run `contextual-agent-generator--project-1` to apply the plan."
8. Top 3 unresolved questions the user might want to answer later to
   sharpen the plan (e.g., "what's the staleness tolerance for the
   product catalog index?")

For monorepos, present the results as a tree matching the input layout:

```
<target>/
├─ contextual-agent-generator--project-1               (archetype: agent+memory, SDK: typescript)
├─ contextual-agent-generator--project-2               (archetype: rag-knowledge-base, SDK: python)
└─ contextual-agent-generator--project-2--project-3    (archetype: voice-context-flywheel, SDK: typescript)
```

## Single-project vs monorepo — summary

- **Step 3 handles both.** Its output is the authoritative list of
  projects. Steps 4–7 run once per row.
- **Don't create a skill for the monorepo wrapper.** If
  `detect_projects.sh` returned zero rows *and* the user asked for a
  retrofit, ask whether they meant greenfield rather than fabricating
  a wrapper-level skill — a cross-project agent plan would have an
  incoherent `groupName` schema and an unbuildable scaffold.
- **Independent skills.** Each generated child stands alone — no
  cross-skill imports — so users can install just the ones relevant
  to the projects they own.

## Regenerate

When the user asks to regenerate (e.g., "refresh the contextual agent
plan for project-1"), re-run Steps 0–7 on the same target. Step 1 is
shorter the second time: ask only what's changed (new capabilities,
new data sources, scale shifts, archetype mis-match observed in
practice).

Re-running overwrites everything under
`.agents/skills/contextual-agent-generator--<slug>/` *except* a
`custom/` subdirectory if present — the user can park hand-tuned
overrides (custom `groupName` rules, edited scaffolds, project-specific
runbook additions) in `custom/` and they survive regeneration. Tell the
user about this on first generation so they know where to put edits.

## Triggering from other skills

Skills that ship an LLM call (a code-writer, a voice agent, a deal-flow
assistant) can invoke `contextual-agent-generator--<slug>` as a
**setup pre-step** to plan how Alchemyst should wrap their agent. If
the child skill for the project doesn't exist yet, prompt the user to
run `contextual-agent-generator` first — don't fall back to a generic
"add a vector DB" recipe, because that defeats the per-project
`groupName` design and the matched archetype.

## Distinction from neighbouring skills

- [context-api](../context-api/SKILL.md) — *documents* the Alchemyst
  Context Layer SDK and context arithmetic. Use it when the user is
  working at the primitive level (writing a `search_context` call by
  hand, debugging `groupName` queries). This skill *plans projects*
  built on top of those primitives.
- [prompt-harness-generator](../prompt-harness-generator/SKILL.md) —
  rewrites incoming draft prompts. After the agent is shipped, pair
  the two: this skill plans the agent; that skill hardens prompts
  going into it.
- [edge-case-testing-generator](../edge-case-testing-generator/SKILL.md)
  — produces an adversarial test corpus for the agent's prompt. Run
  it after the agent is built to verify it doesn't regress on the
  business-critical edge cases.
- [code-cloner](../code-cloner/SKILL.md) → `code-writer--{repo}` — for
  retrofits, run `code-cloner` first so the file edits in the
  `IMPLEMENTATION_PLAN.md` match the target codebase's style.
