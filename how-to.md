# How to Use AlchemystAI Skills

This guide walks developers through using the skills in this repository. If you just want to install skills, see [README.md](README.md). This document explains **how the skills actually work** and what to expect when you run them.

---

## Table of Contents

1. [Core Concept: Meta Skills vs Direct Skills](#core-concept-meta-skills-vs-direct-skills)
2. [Context Layer Development](#context-layer-development)
3. [Skill Reference](#skill-reference)
4. [Quick Start](#quick-start)

---

## Core Concept: Meta Skills vs Direct Skills

Skills in this repo fall into two categories:

**Direct skills** do a specific job when invoked. You ask Claude a question about the Context Layer SDK, it uses [skills/context-api](skills/context-api/SKILL.md) and walks you through the primitive.

**Meta skills** generate other skills. The output of a meta skill is a new skill tailored to your specific project. You run the meta skill once (or occasionally), and the generated skill gets used repeatedly.

The example in this repo:

```
contextual-agent-generator (meta skill)
    │
    ▼  interviews you, matches an archetype, scans the repo
contextual-agent-generator--{your-repo} (generated child skill)
    │
    ▼  applies the plan, scaffolds code, runs verification
```

This means **you don't run `contextual-agent-generator` repeatedly** — you run it once per project, then run the generated child skill to actually apply the plan.

---

## Context Layer Development

Two skills cover this space at different altitudes:

- **[skills/context-api](skills/context-api/SKILL.md)** — primitive-level reference. Use when you're writing a `search_context` call by hand, debugging `groupName` queries, or comparing Alchemyst against memory libraries / plain RAG.
- **[skills/contextual-agent-generator](skills/contextual-agent-generator/SKILL.md)** — meta skill that plans whole agent projects on top of Alchemyst. Use when starting a new context-aware agent or retrofitting one into an existing repo.

### Building or retrofitting an agent on Alchemyst (`contextual-agent-generator`)

> "Build a context-aware agent on Alchemyst for this repo."
> or
> "Add the Context Layer to my chatbot — minimum changes."

The meta skill walks the user through:

1. **Autonomy mode** — hands-off (one batch of questions then go) or interactive (check-ins between steps). Default: interactive for retrofits, hands-off for greenfield.
2. **Interview** — end goal, capabilities, data sources, user/tenant boundaries, scale & freshness, surrounding stack, off-limits.
3. **Topology detection** — single-repo, monorepo, or greenfield (uses `detect_projects.sh`).
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

   Naming follows the standard monorepo convention:

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

## Skill Reference

| Skill | Category | What It Does | Depends On |
|-------|----------|--------------|------------|
| [context-api](skills/context-api/SKILL.md) | Direct / Dev / API | Developer reference for Context Layer integration — `search_context`, `groupName`, document set arithmetic, staleness | Alchemyst SDK |
| [contextual-agent-generator](skills/contextual-agent-generator/SKILL.md) | Meta / Agents | Interviews the user, matches an Alchemyst archetype, generates a per-project `contextual-agent-generator--{repo}` skill with `groupName` design + scaffolds (Py / TS) + verification recipe | — |

---

## Quick Start

**If you want to integrate the Context Layer at the SDK level:**
1. "Help me integrate the Context Layer API" (runs `context-api`)
2. Follow SDK setup and common patterns

**If you want to build or retrofit an agent on Alchemyst:**
1. "Build a context-aware agent on Alchemyst for this repo" (runs `contextual-agent-generator`)
2. The skill interviews you, matches an archetype, generates a `contextual-agent-generator--{repo}` skill
3. Run that child skill to apply the plan and verify end-to-end
