# alchemyst-skills

A collection of [Claude Code](https://claude.com/claude-code) skills for
building on the [Alchemyst](https://getalchemystai.com) Context Layer —
the API that turns context into a computable primitive.

These skills give Claude the domain knowledge and scaffolding it needs
to plan and ship context-aware agents on Alchemyst, instead of falling
back on generic RAG or memory-library recipes.

## Skills in this repo

| Skill | Kind | What it does |
|-------|------|--------------|
| [skills/context-api](skills/context-api/SKILL.md) | direct | Developer reference for the Context Layer SDK — `search_context`, `groupName`, document set arithmetic, staleness. Trigger when working at the primitive level. |
| [skills/contextual-agent-generator](skills/contextual-agent-generator/SKILL.md) | meta | Interviews the user about an agent they want to build (or retrofit) on Alchemyst, matches their goal to a documented archetype, and **generates a project-scoped child skill** that plans and scaffolds the implementation end-to-end. |

The two are complementary: `context-api` documents the *primitive*;
`contextual-agent-generator` plans *projects* built on top of it. See
[how-to.md](how-to.md) for the meta-vs-direct distinction and how to
install / author / extend skills in this repo.

## Quick start
Install it using the npx skills executable.
```bash
npx skills add alchemyst-ai/alchemyst-skills
```

## Developer Setup
Clone the repo, then symlink the skills you want into Claude Code's
skills directory:

```bash
git clone https://github.com/alchemyst-ai/alchemyst-skills.git
cd alchemyst-skills

# user-scoped: available to all your projects
mkdir -p ~/.claude/skills
ln -sfn "$PWD/skills/context-api"                 ~/.claude/skills/context-api
ln -sfn "$PWD/skills/contextual-agent-generator"  ~/.claude/skills/contextual-agent-generator
```

Or scope to a single project:

```bash
mkdir -p .claude/skills
ln -sfn "<abs-path>/alchemyst-skills/skills/context-api"                .claude/skills/context-api
ln -sfn "<abs-path>/alchemyst-skills/skills/contextual-agent-generator" .claude/skills/contextual-agent-generator
```

Once installed, invoke from a Claude Code session by description (e.g.
*"build a context-aware agent on Alchemyst for this repo"*) — Claude
matches the request against each skill's frontmatter `description` and
loads the relevant `SKILL.md`.

## Repo layout

```
alchemyst-skills/
├── README.md                          this file
├── how-to.md                          install / author / extend skills
├── .github/workflows/validate.yml     CI: SKILL.md frontmatter + kebab-case names
└── skills/
    ├── context-api/
    │   └── SKILL.md
    └── contextual-agent-generator/
        ├── SKILL.md
        ├── README.md
        ├── references/                authoritative reference material the skill loads on demand
        ├── scripts/                   shell helpers (project detection, signal scan, slugify)
        └── templates/child-skill/     templates rendered into the generated child skill
```

## Validation

Every PR touching `skills/**` runs
[.github/workflows/validate.yml](.github/workflows/validate.yml), which
checks:

- each `skills/<name>/SKILL.md` exists and has YAML frontmatter
- frontmatter contains `name:` and `description:`
- the directory name is kebab-case (`^[a-z0-9]+(-[a-z0-9]+)*$`)

Run the same checks locally before pushing:

```bash
act -W .github/workflows/validate.yml    # if you have nektos/act
# or just inline the script from validate.yml
```

## License

This repository is MIT licensed — see [LICENSE](LICENSE) for details.
