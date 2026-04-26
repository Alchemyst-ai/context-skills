# How to Use AlchemystAI Skills

This guide walks developers through using the skills in this repository — individually and as composable workflows. If you just want to install skills, see [README.md](README.md). This document explains **how the skills actually work together** and what to expect when you run them.

---

## Table of Contents

1. [Core Concept: Meta Skills vs Direct Skills](#core-concept-meta-skills-vs-direct-skills)
2. [Website Performance Optimization Workflow](#website-performance-optimization-workflow)
3. [Voice Agent Workflows](#voice-agent-workflows)
4. [Prompt Engineering Workflows](#prompt-engineering-workflows)
5. [Delivery Operations Workflows](#delivery-operations-workflows)
6. [Context Layer Development](#context-layer-development)
7. [Load Testing with k6](#load-testing-with-k6)
8. [Terraform Compliance Workflow](#terraform-compliance-workflow)
9. [Skill Reference](#skill-reference)

---

## Core Concept: Meta Skills vs Direct Skills

Skills in this repo fall into two categories:

**Direct skills** do a specific job when invoked. You ask Claude to debug a voice agent, it uses `voice-agent-debug` and walks you through troubleshooting.

**Meta skills** generate other skills. The output of a meta skill is a new skill tailored to your specific project. You run the meta skill once (or occasionally), and the generated skill gets used repeatedly.

The key example:

```
code-cloner (meta skill)
    │
    ▼  analyzes your repo's coding style
code-writer--{your-repo} (generated skill)
    │
    ▼  used by other skills that write code
website-auto-improvement (direct skill that consumes the generated skill)
```

This means **you cannot jump straight to `website-auto-improvement`**. You need to run `code-cloner` first to produce a `code-writer` skill for your project. Only then can the auto-improvement loop write code that matches your codebase's conventions.

---

## Website Performance Optimization Workflow

This is the most involved multi-skill workflow. It chains four skills together to autonomously improve your website's PageSpeed scores.

### Prerequisites

- Node.js installed
- A Google PageSpeed API key (get one from [Google Cloud Console](https://console.cloud.google.com/apis/credentials))
- Your site deployed at a public URL
- The `latex-document` skill installed (for PDF reports)

### Step 1: Generate a Code Writer for Your Project

**Skill used:** `code-cloner`

Before any code changes happen, you need a code-writer skill that understands your project's conventions. Open your project directory and tell Claude:

> "Analyze this codebase and generate a code-writer skill for it."

Claude will:
1. Run `analyze_structure.sh` to map out languages, file tree, and naming patterns
2. Run `sample_files.sh` to pick ~30 representative files across the codebase
3. Deep-read those files to extract naming conventions, formatting, import style, error handling, architecture patterns, testing patterns, and more
4. Generate a `code-writer--{your-repo-name}` skill with a full style guide
5. Install it as a symlink in `.claude/skills/`

**Output:** A new skill at `.agents/skills/code-writer--{repo-name}/SKILL.md`

This only needs to be done once per project (re-run if the codebase style changes significantly).

### Step 2: Run a PageSpeed Baseline

**Skill used:** `pagespeed-skill`

> "Run a PageSpeed test on https://your-site.com for both desktop and mobile."

Claude will:
1. Check for `PAGESPEED_API_KEY` in `scripts/.env.local` (prompts you if missing)
2. Run `run-pagespeed.js` for each strategy
3. Parse scores, Core Web Vitals, opportunities, and diagnostics
4. Generate a PDF report via `latex-document` with color-coded scores and prioritized suggestions

**Output:** JSON results + a professional PDF report with scores and fix recommendations.

This step is optional if you go straight to auto-improvement, but useful for a standalone audit.

### Step 3: Run the Auto-Improvement Loop

**Skill used:** `website-auto-improvement` (which internally uses `code-writer--{repo}` + `pagespeed-skill`)

> "Run the website auto-improvement loop on https://your-site.com."

Claude enters an autonomous loop:

```
ITERATION N:
  MEASURE  → PageSpeed test (desktop + mobile)
  DIAGNOSE → Rank issues by impact tier (Critical > High > Medium)
  FIX      → Apply code changes using your code-writer style guide
  VERIFY   → npm run build (catch errors before deploying)
  REPORT   → Log changes and score deltas

  → Loop back to MEASURE (up to 3-4 iterations)
  → Stop when scores plateau (<3 point improvement)
```

**What it fixes per iteration (one category at a time):**

| Priority | Examples | Typical Gain |
|----------|----------|--------------|
| Critical | Render-blocking CSS/JS, unoptimized images, huge JS bundles | 15-30 pts |
| High | Layout shifts, long main-thread tasks, missing cache headers | 10-20 pts |
| Medium | Font optimization, preconnect hints, accessibility perf | 5-10 pts |

**Between iterations:** You need to deploy the changes (push to git if using Vercel auto-deploy) so PageSpeed can test the live site. Claude will tell you when to deploy and wait.

**When it stops:** After 3-4 iterations or when scores plateau, Claude presents a summary of all changes, remaining issues (infrastructure-level, third-party scripts, architectural), and asks whether to continue.

### The Full Picture

```
You (developer)
  │
  ├─ Step 1: "Analyze this codebase" ──────────► code-cloner
  │                                                  │
  │                                     code-writer--{repo} skill created
  │
  ├─ Step 2 (optional): "Run PageSpeed" ──────► pagespeed-skill
  │                                                  │
  │                                         PDF report + baseline scores
  │
  └─ Step 3: "Run auto-improvement" ──────────► website-auto-improvement
                                                     │
                                          uses: code-writer--{repo} (for style)
                                          uses: pagespeed-skill (for measurement)
                                          uses: optimization-playbook.md (for fix recipes)
                                                     │
                                          iterates: measure → fix → verify → deploy → repeat
```

---

## Voice Agent Workflows

### Scoping a New Voice Campaign

**Skill used:** `campaign-scoping`

> "Help me scope a new outbound voice campaign for [client]."

Claude walks through a structured checklist:
- **Client requirements** — use case, volume, languages, timezone/DND, CRM integration
- **Agent configuration** — preset, voice selection, knowledge base, data extraction fields, escalation rules
- **Success criteria** — KPIs, target metrics, reporting cadence
- **Technical requirements** — telephony setup, contact list format, webhooks, Context Layer needs

Output: A scoping document with effort estimation (Standard: same day / Custom: 2-3 days / Enterprise: 1-2 weeks).

### Writing and Tuning Voice Agent Prompts

Two skills serve this purpose depending on the platform:

**For Vapi, Bland, Retell, or ElevenLabs:** use `voice-prompt-optimizer`

> "Write a voice agent prompt for appointment booking on Vapi."

**For OpenAI Realtime models (gpt-4o-realtime-preview / gpt-4o-mini-realtime-preview):** use `gpt-realtime-prompt-optimizer`

> "Write a realtime voice prompt for service reminder calls using the mini model."

Both skills follow the same human-in-the-loop cycle:

```
Draft script → Generate prompt → You review
       ▲                              │
       │                    Approved? ─┤
       │                              │
       └── No: collect edits ◄────── No
                                      │
                                     Yes
                                      │
                              Load into platform
                              Make test call
                              Share transcript
                                      │
                              Call good? ──► Yes → Save final prompt
                                      │
                                     No → Diagnose failure → Give edits → Re-draft
```

Key differences between the two prompt skills:
- `voice-prompt-optimizer` produces platform-agnostic prompts (works across Vapi, Bland, Retell, ElevenLabs)
- `gpt-realtime-prompt-optimizer` produces prompts specifically structured for OpenAI's realtime API, with model-specific patterns (mini uses step-labeled flows + TTS formatting; realtime uses phase-based flows + active listening cues)

### Debugging a Live Voice Agent

**Skill used:** `voice-agent-debug`

> "Calls are dropping mid-conversation on the production agent."

Claude debugs by symptom:
- **High latency** — checks STT delay, LLM inference, TTS synthesis, cache hit rate
- **Calls dropping** — checks LiveKit room state, GCP health, network traces
- **Wrong responses** — checks knowledge base, prompt template, Data Extractor config, context scoping
- **TTS pronunciation** — checks voice ID, SSML hints, fallback config
- **Campaign underperformance** — pulls dashboard, reviews bottom-quartile calls, checks timing/DND/scripts

### Voice Workflow Sequence (New Campaign, End to End)

```
campaign-scoping          "What are we building?"
        │
        ▼
scoping-playbook          "How do we build it?" (8-step pipeline)
        │
        ▼
voice-prompt-optimizer    "Tune the agent prompt" (iterative test calls)
   or gpt-realtime-prompt-optimizer
        │
        ▼
client-handoff            "Hand off to the client" (onboarding checklist)
        │
        ▼
voice-agent-debug         "Fix issues in production" (as needed)
```

---

## Prompt Engineering Workflows

Two meta skills work as a pair — one **rewrites** incoming prompts, the other **tests** them. Both follow the same `code-cloner` → `code-writer--{repo}` pattern: run the meta skill once per project, get back a child skill scoped to that project's glossary, business context, and constraints.

### prompt-harness-generator → child harness per project

**Skill used:** `prompt-harness-generator`

> "Generate a prompt harness for this repo."

The meta skill interviews you (task types, dictation vs typed input, glossary, constraints, house style, iteration policy), then scans the repo for existing prompts, LLM call sites, and glossary candidates. It writes a child skill at `.agents/skills/prompt-harness-generator--{slug}/` with:

- `GLOSSARY.md` — project terms with likely mis-transcriptions
- `CHECKS.md` — lint rules (negation polarity, homophones, named-entity verification, project-specific checks)
- `REFINE.md` — the rewrite recipe (style, structure, output contract)
- `examples/` — well-formed prompts and anti-patterns

**What the generated harness does** when invoked on a draft prompt:

1. Reads the draft and surfaces ambiguities
2. Flags likely mis-transcribed words against the glossary (`Alchemyst` vs `alchemist`, `K6` vs `K-six`)
3. Enforces project constraints silently (forbidden actions, secrets, output format)
4. Returns an improved prompt with a side-by-side diff and a list of inferred-but-not-stated assumptions

It **never silently rewrites** — every change is shown so you can reject the interpretation. It also refuses to forward prompt-injection attempts.

### edge-case-testing-generator → child test harness per project

**Skill used:** `edge-case-testing-generator`

> "Build a prompt edge-case test harness for this project."

The meta skill interviews you about (1) the prompt under test, (2) business context — what the agent does, who uses it, what bad answers cost; (3) input modality, (4) languages/locale, (5) off-limits topics, (6) glossary seeds, (7) observed failures, (8) coverage budget. It then scans for prompt files, regulated-domain signals (HIPAA / PII / payments / minors), and tone examples in transcripts.

It writes a child skill at `.agents/skills/edge-case-testing-generator--{slug}/` with:

- `BUSINESS_CONTEXT.md` — what the company does, off-limits topics
- `GLOSSARY.md` — project terms used to seed realistic probes
- `TEST_CASES.md` — the curated edge-case corpus (the heart of the harness)
- `GRADING.md` — PASS/WARN/FAIL/CRITICAL rubric
- `examples/` — sample passing and failing responses with named failure modes

**Default ~40-probe corpus** (scaled to your coverage budget):

| Category | Default share |
|----------|---------------|
| Transcription / homophone / polarity | ~25% |
| Scope and ambiguity | ~15% |
| Prompt-injection / jailbreak | ~10% |
| Off-limits topics & competitor handling | ~10% |
| Regulated domain (PHI/PCI/legal/minors) | 0–20% (only if signal present) |
| Locale (numbers, dates, code-switching) | ~10% |
| Tone / panic / sarcasm / hostility | ~10% |
| Observed-failure regressions | as many as you provide |
| Boundary inputs (empty, max-len, unicode) | ~5% |
| Business-context-specific (handcrafted) | ~5–15% |

Every test case carries a **named failure mode** (e.g., `homophone-pull-vs-pool`, `address-readback-skipped`) — a case without one is a case you can't act on.

### Pairing the two

These skills compose:

```
draft prompt
     │
     ▼
prompt-harness-generator--{slug}     # rewrite & lint
     │
     ▼  improved prompt + diff
ship to LLM call site
     │
     ▼
edge-case-testing-generator--{slug}  # probe with adversarial corpus
     │
     ▼  PASS / WARN / FAIL / CRITICAL verdict
deploy or iterate
```

For voice agents specifically, run after `voice-prompt-optimizer` or `gpt-realtime-prompt-optimizer` to catch failure modes those iteration loops won't surface (mis-transcription, regulated-domain probes, business-context-specific failures).

### Naming for monorepos

Both meta skills follow the same naming as `test-infra-generator`:

| Input | Generated skill(s) |
|-------|--------------------|
| single repo `my-app` | `prompt-harness-generator--my-app` |
| monorepo `project-1` + `project-2` | `prompt-harness-generator--project-1`, `prompt-harness-generator--project-2` |
| nested `project-2/project-3` | `prompt-harness-generator--project-2--project-3` |

User-edited files placed under a `custom/` subdirectory survive regeneration.

---

## Delivery Operations Workflows

### Taking a Deal from Signed to Live

Three skills cover the delivery pipeline in sequence:

**1. Scoping** (`campaign-scoping` + `scoping-playbook`)

After a deal is signed, use `scoping-playbook` for the 8-step fulfillment pipeline:

1. Deal intake (Harsh, same day)
2. Transcript-to-spec conversion (automated)
3. Spec review and gap analysis
4. Build assignment (based on capacity)
5. Build (assigned engineer)
6. QA (minimum 10 test calls)
7. Client approval (recorded demo + dashboard walkthrough)
8. Go-live and monitoring (48h active, then standard support)

**2. Handoff** (`client-handoff`)

> "Run the client handoff checklist for [client]."

Covers pre-handoff (sales side), the handoff meeting (30 min max), and post-handoff setup (Day 0 through go-live). Includes a 2-week Context Layer upsell checkpoint.

### Escalation Reference

| Level | Owner | Scope |
|-------|-------|-------|
| L1 | Debayan | Production voice issues, agent config |
| L2 | Saumitra | Infrastructure, scaling, GCP |
| L3 | Anuran | Architecture decisions, cross-system bugs |

---

## Context Layer Development

Two skills cover this space at different altitudes:

- **`context-api`** — primitive-level reference. Use when you're writing a `search_context` call by hand, debugging `groupName` queries, or comparing Alchemyst against memory libraries / plain RAG.
- **`contextual-agent-generator`** — meta skill that plans whole agent projects on top of Alchemyst. Use when starting a new context-aware agent or retrofitting one into an existing repo.

### Building or retrofitting an agent on Alchemyst (`contextual-agent-generator`)

> "Build a context-aware agent on Alchemyst for this repo."
> or
> "Add the Context Layer to my chatbot — minimum changes."

The meta skill walks the user through:

1. **Autonomy mode** — hands-off (one batch of questions then go) or interactive (check-ins between steps). Default: interactive for retrofits, hands-off for greenfield.
2. **Interview** — end goal, capabilities, data sources, user/tenant boundaries, scale & freshness, surrounding stack, off-limits.
3. **Topology detection** — single-repo, monorepo, or greenfield (uses the same `detect_projects.sh` as the other meta skills).
4. **Signal scan (retrofits only)** — finds the LLM call site, the system prompt, language signal (`tsconfig.json` → TypeScript, else Python), pre-existing context layers (Pinecone / Mem0 / Zep) to coexist with or replace.
5. **Archetype match** — picks one of:

   | Archetype | Trigger |
   |-----------|---------|
   | RAG knowledge base | Q&A over docs / tickets / a corpus |
   | Agent + persistent memory | "remembers me", per-session continuity |
   | Personalized chat | per-user behaviour change |
   | Voice + context flywheel | voice agent + transcripts; the moat archetype |
   | Summarization / research | long-form reports across many docs |

   Async ingestion is layered on top as a modifier when scale > 10k docs or refresh < 1 hour.

6. **Generate** — writes a child skill at `.agents/skills/contextual-agent-generator--{slug}/` with:

   - `CAPABILITIES.md` — what the agent must do
   - `ARCHITECTURE.md` — matched archetype + `groupName` schema with rationale per layer
   - `IMPLEMENTATION_PLAN.md` — for greenfield: file tree to produce; for retrofit: numbered file-level edit list, one tool definition + one system-prompt sentence + handler wiring (the "two-surface theorem" — typically <10 file edits)
   - `RUNBOOK.md` — universal verification (API key, `groupName` round-trip, end-to-end search) + archetype-specific checks
   - `scaffolds/` — runnable starter code in Python *or* TypeScript (never both)
   - `examples/matched-archetype.md` — canonical flow for the matched pattern

   Naming follows the same monorepo convention as the other meta skills:

   | Input | Generated child(ren) |
   |-------|----------------------|
   | single repo `my-app` | `contextual-agent-generator--my-app` |
   | `project-1`, `project-2` | `contextual-agent-generator--project-1`, `contextual-agent-generator--project-2` |
   | nested `project-2/project-3` | `contextual-agent-generator--project-2--project-3` |

The child skill is what you run later to actually apply the plan and run verification — it inherits the autonomy choice from the meta skill.

### Picking the SDK

- **Existing repo**: `tsconfig.json` present → TypeScript; otherwise Python. (If the repo is Go-only with an LLM call, the skill asks.)
- **Greenfield**: the skill asks; default Python if the user has no preference.

One SDK per child skill — never both. If you need the other language, regenerate.

### When to use `context-api` instead

If you're not building a whole project — just need to write or debug a `search_context` call, understand `groupName` shape, or explain Alchemyst's positioning vs Mem0 / Zep / plain RAG — go straight to `context-api`. It's the SDK reference, not the project planner.

### Pairing with the other meta skills

```
contextual-agent-generator    # plan + scaffold the agent
       │
       ▼  agent ships
prompt-harness-generator      # rewrite incoming draft prompts
       │
       ▼
edge-case-testing-generator   # probe the deployed prompt with adversarial cases
```

For voice agents, also pair with `voice-prompt-optimizer` / `gpt-realtime-prompt-optimizer` for the prompt-tuning loop.

### Direct primitive-level integration (`context-api`)

> "Help me integrate the Context Layer API into this application."

The Context Layer is AlchemystAI's infrastructure API that treats context as a computable primitive. The skill guides you through:

- **Core operations** — search, upsert, delete within a `groupName` scope
- **Context arithmetic** — union, intersection, difference over document sets
- **SDK usage** — `AlchemystClient` setup, search queries, document upsertion
- **Common patterns** — Voice + Context (call transcripts feed future calls), standalone API integration

```python
from alchemyst import AlchemystClient

client = AlchemystClient(api_key="...")

# Search within a group
results = client.search_context(
    group_name="user-123",
    query="previous purchase history",
    top_k=5
)

# Upsert documents
client.upsert_context(
    group_name="user-123",
    documents=[{"content": "...", "metadata": {"source": "crm", "ts": "..."}}]
)
```

The Context Layer is positioned as the expansion play after voice campaigns — voice generates call data, Context Layer makes future calls smarter.

---

## Load Testing with k6

This workflow is another meta-skill pattern, analogous to `code-cloner` → `code-writer--{repo}`: you run `test-infra-generator` once per codebase and get a project-specific k6 testing skill back.

### Skill used

**`test-infra-generator`** — analyzes a codebase's API surface + business flows and produces a `k6-testing--{slug}` skill per project.

### What you run

In a repo or monorepo:

> "Generate k6 tests for this repo."

Claude will:

1. Walk the repo and find every project root (by manifests like `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, etc.).
2. Scan each project for routes (Express, Fastify, NestJS, Hono, Next.js, FastAPI, Flask, Django, Go net/http/gin/echo/chi/fiber, Rails, Spring, Laravel), OpenAPI/Swagger specs, Postman collections, auth middleware, and e2e test directories.
3. Infer business flows from integration tests, OpenAPI tags, controller call graphs, auth-gated chains, and CRUD resource lifecycles (see `references/flow-patterns.md`).
4. Generate a `k6-testing--{slug}` skill per project with ready-to-run `smoke.js`, `load.js`, `stress.js`, `spike.js`, `soak.js`, and one script per inferred flow.
5. Install via symlink in `.claude/skills/`.

### Naming

| Input                                           | Generated skill(s)                               |
|-------------------------------------------------|--------------------------------------------------|
| single repo `my-app`                            | `k6-testing--my-app`                             |
| monorepo with `project-1` + `project-2`         | `k6-testing--project-1`, `k6-testing--project-2` |
| nested `project-2/project-3`                    | `k6-testing--project-2--project-3`               |

The wrapper/monorepo root is **not** part of the chain — only the project directory names appear.

### Running the generated tests

```bash
cd .agents/skills/k6-testing--{slug}/k6
cp .env.example .env   # fill in BASE_URL + creds
set -a && source .env && set +a
k6 run flows/smoke.js  # always run smoke first
k6 run flows/load.js
k6 run flows/{flow-slug}.js
```

### Regenerate

When the API surface changes:

> "Regenerate k6 tests for {project-name}."

This re-runs `test-infra-generator` and overwrites the generated skill (manual edits should live under `k6/custom/`, which the generator leaves alone).

---

## Terraform Compliance Workflow

**Skill used:** `sre-iac-terraform-compliance`

> "Make this Terraform project SOC 2 + HIPAA compliant."

This is another meta skill: it produces a compliant **fork** of an existing Terraform project as a `terraform-compliance-infrastructure--{slug}` skill, rather than mutating the source. Supports 40+ frameworks including SOC 2, HIPAA, PCI DSS, NIST 800-53, CIS, ISO 27001, GDPR, and NIS2.

The skill scans the input Terraform for resources covered by the requested framework(s), generates compliant variants (encryption at rest, audit logging, IAM least-privilege, network segmentation, retention policies), and writes them under `.agents/skills/terraform-compliance-infrastructure--{slug}/` along with a compliance matrix mapping each control to the resource that satisfies it.

The source project is untouched — you review the fork, diff against the original, and merge what you accept.

---

## Skill Reference

| Skill | Category | What It Does | Depends On |
|-------|----------|--------------|------------|
| `code-cloner` | Meta / Dev Tool | Analyzes a codebase and generates a `code-writer` skill | — |
| `website-auto-improvement` | Performance | Autonomous PageSpeed optimization loop | `code-writer--{repo}`, `pagespeed-skill` |
| `pagespeed-skill` | Performance | Runs PageSpeed tests, generates PDF reports | `PAGESPEED_API_KEY`, `latex-document` |
| `voice-agent-debug` | Voice / Ops | Debugs live voice agent issues by symptom | — |
| `campaign-scoping` | Voice / Sales | Scopes new outbound voice campaigns | — |
| `voice-prompt-optimizer` | Voice / Tuning | Iterative prompt optimization for Vapi, Bland, Retell, ElevenLabs | — |
| `gpt-realtime-prompt-optimizer` | Voice / Tuning | Prompt optimization for OpenAI realtime models | — |
| `prompt-harness-generator` | Meta / Prompts | Generates a per-project `prompt-harness-generator--{repo}` skill that lints/rewrites incoming draft prompts | — |
| `edge-case-testing-generator` | Meta / Prompts | Generates a per-project `edge-case-testing-generator--{repo}` skill with a curated adversarial test corpus + grading rubric | — |
| `contextual-agent-generator` | Meta / Agents | Interviews the user, matches an Alchemyst archetype, generates a per-project `contextual-agent-generator--{repo}` skill with `groupName` design + scaffolds (Py / TS) + verification recipe | — |
| `scoping-playbook` | Delivery | 8-step fulfillment pipeline from deal to go-live | — |
| `client-handoff` | Delivery | Onboarding checklist from signed deal to live campaign | — |
| `context-api` | Dev / API | Developer guide for Context Layer integration | Alchemyst SDK |
| `test-infra-generator` | Meta / Testing | Analyzes API surface + flows and generates a `k6-testing--{repo}` skill per project | `k6` (installed separately) |
| `k6-testing--{repo}` | Testing | Project-specific k6 load/stress/spike/soak + business-flow scripts | Generated by `test-infra-generator` |
| `sre-iac-terraform-compliance` | Meta / SRE | Produces a compliant fork of a Terraform project as a `terraform-compliance-infrastructure--{slug}` skill | — |

---

## Quick Start

**If you want to optimize a website:**
1. Install skills: `npx skills add alchemyst-ai/skills`
2. In your project: "Analyze this codebase and generate a code-writer skill" (runs `code-cloner`)
3. Then: "Run the website auto-improvement loop on https://your-site.com"

**If you want to build a voice campaign:**
1. "Help me scope a voice campaign for [client]" (runs `campaign-scoping`)
2. "Write a voice agent prompt for [platform]" (runs the appropriate prompt optimizer)
3. Test, iterate, deploy
4. "Run the client handoff checklist" (runs `client-handoff`)

**If you want to debug a voice issue:**
1. Describe the symptom: "Calls are dropping" / "Agent is slow" / "Agent says wrong things"
2. Claude uses `voice-agent-debug` to walk through diagnosis

**If you want to integrate the Context Layer:**
1. "Help me integrate the Context Layer API" (runs `context-api`)
2. Follow SDK setup and common patterns

**If you want to build or retrofit an agent on Alchemyst:**
1. "Build a context-aware agent on Alchemyst for this repo" (runs `contextual-agent-generator`)
2. The skill interviews you, matches an archetype, generates a `contextual-agent-generator--{repo}` skill
3. Run that child skill to apply the plan and verify end-to-end

**If you want to harden a prompt before shipping:**
1. "Generate a prompt harness for this repo" (runs `prompt-harness-generator`)
2. "Build an edge-case test harness for this project" (runs `edge-case-testing-generator`)
3. Use the generated `prompt-harness-generator--{repo}` to rewrite drafts; use the generated `edge-case-testing-generator--{repo}` to probe the result before deploy

**If you need compliant Terraform:**
1. "Make this Terraform project compliant with [SOC 2 / HIPAA / PCI DSS / …]" (runs `sre-iac-terraform-compliance`)
2. Review the generated `terraform-compliance-infrastructure--{slug}` fork and merge what you accept
