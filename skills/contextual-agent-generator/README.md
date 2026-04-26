# contextual-agent-generator

A meta skill that interviews the user about an AI agent they want to
build (or retrofit) on the [Alchemyst](https://getalchemystai.com)
platform, matches their goals against the platform's documented
archetypes, and generates a project-scoped child skill that plans and
scaffolds the implementation.

## What you get

For every project (existing repo or greenfield), a child skill at:

```
.agents/skills/contextual-agent-generator--<slug>/
├── SKILL.md
├── README.md
├── CAPABILITIES.md           # what the agent must do
├── ARCHITECTURE.md           # archetype + groupName design
├── IMPLEMENTATION_PLAN.md    # ordered, file-level plan
├── RUNBOOK.md                # verification recipe
├── scaffolds/                # starter code (Python OR TypeScript, never both)
└── examples/
```

For monorepos, one child skill per project, with double-hyphen-joined
nesting:

| Input                                    | Generated child(ren)                                        |
|------------------------------------------|-------------------------------------------------------------|
| single repo `my-app`                     | `contextual-agent-generator--my-app`                        |
| `project-1`, `project-2`                 | `contextual-agent-generator--project-1`, `contextual-agent-generator--project-2` |
| nested `project-2/project-3`             | `contextual-agent-generator--project-2--project-3`          |

## Quick start

In a repo (retrofit) or empty directory (greenfield):

> "Build a context-aware agent on Alchemyst for this repo."

The skill walks through:

1. **Autonomy**: hands-off (one batch of questions then go) or
   interactive (check in between steps). Default is interactive for
   retrofits, hands-off for greenfield.
2. **Interview**: end goal, capabilities, data sources, user/tenant
   boundaries, scale, surrounding stack, off-limits.
3. **Detect topology**: monorepo or single project.
4. **Scan signals** (retrofits): finds the LLM call site, the system
   prompt, language signal (`tsconfig.json` → TypeScript, else
   Python), any pre-existing context layer.
5. **Match archetype**: one of RAG / agent+memory / personalized chat
   / voice+context flywheel / summarization. Async ingestion is a
   modifier on top.
6. **Generate**: writes the child skill with the matched archetype's
   `groupName` schema, runnable scaffolds in the chosen SDK, and a
   verification recipe.

## When to use this skill

- Build a context-aware AI agent on Alchemyst from scratch
- Add Alchemyst's `search_context` to an existing chatbot or voice agent
- Plan an agent that needs persistent memory or per-user personalization
- Retrofit RAG over organizational data into an existing LLM call
- Compare which Alchemyst pattern fits a use case

## When **not** to use this skill

- The user just wants a chatbot with no context layer — Alchemyst is
  overkill.
- The user wants to replace OpenAI with Alchemyst — Alchemyst is a
  context layer, not an LLM.
- The user has a specific, narrow SDK question — point them at the
  sibling [context-api](../context-api/SKILL.md) skill instead.

## Files

| Path                                     | Purpose                                          |
|------------------------------------------|--------------------------------------------------|
| [SKILL.md](SKILL.md)                     | Main meta-skill instructions Claude reads.       |
| [references/interview-questions.md](references/interview-questions.md) | The interview script.   |
| [references/alchemyst-patterns.md](references/alchemyst-patterns.md) | SDK surface + `groupName` design rules. |
| [references/agent-archetypes.md](references/agent-archetypes.md) | The archetype catalogue + matcher. |
| [references/minimum-delta.md](references/minimum-delta.md) | Retrofit recipe: the two-surface theorem. |
| [references/autonomy-modes.md](references/autonomy-modes.md) | Hands-off vs interactive behaviour per step. |
| [scripts/detect_projects.sh](scripts/detect_projects.sh) | Monorepo / project-root detection. |
| [scripts/scan_agent_signals.sh](scripts/scan_agent_signals.sh) | Surfaces LLM call sites, prompts, language. |
| [scripts/slugify.sh](scripts/slugify.sh) | Slug helper.                                     |
| [templates/child-skill/](templates/child-skill/) | Templates for the generated child skill. |

## Regeneration

Re-running `contextual-agent-generator` overwrites everything under
`.agents/skills/contextual-agent-generator--<slug>/` *except* the
`custom/` subdirectory — user-tuned overrides survive.

## Related skills

- [context-api](../context-api/SKILL.md) — primitives the child uses.
- [prompt-harness-generator](../prompt-harness-generator/SKILL.md) —
  hardens prompts going *into* the agent.
- [edge-case-testing-generator](../edge-case-testing-generator/SKILL.md)
  — adversarial test corpus for the agent's prompt.
- [code-cloner](../code-cloner/SKILL.md) — for retrofits, run first
  so the child's edits match the codebase's style.
