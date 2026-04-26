# Autonomy Modes — hands-off vs interactive

The meta skill asks the user (Step 0) which mode to run in. This file
describes how each mode behaves at every workflow step, and how the
choice threads through to the generated child skill.

---

## Why offer a choice

Different users want different things from the same skill:

- A founder spinning up a prototype on a Saturday wants **hands-off**:
  one batch of questions, then "go". They'll edit the output later.
- A senior engineer retrofitting Alchemyst into a 50-file production
  service wants **interactive**: the cost of a wrong assumption inside
  someone else's code is high, and a mid-step "wait, that file is
  generated, don't touch it" saves hours.

Asking once, up front, is cheaper than guessing wrong on every step.

---

## Defaults

Use these unless the user specifies:

| Mode of project | Default autonomy |
|-----------------|------------------|
| Greenfield      | hands-off        |
| Retrofit        | interactive      |

Reasoning: greenfield has no production code to break and the user can
edit the scaffold. Retrofit edits real files; an extra confirmation
beats an unwanted refactor.

---

## Step-by-step behaviour

### Step 0 — pick mode

Always ask once. Don't ask again at later steps; the choice is
respected throughout.

### Step 1 — interview

| Mode         | Behaviour                                                                 |
|--------------|---------------------------------------------------------------------------|
| hands-off    | Ask only the **starred** questions in [interview-questions.md](interview-questions.md), in one batch. Infer the rest. |
| interactive  | Ask one at a time. Confirm running summary at Q4 (after `groupName` design) and Q8 (before generating). |

In hands-off mode, the final report (Step 8) lists what was inferred
so the user can override.

### Step 2 — identify target

Same in both modes; this is a single-line input from the user.

### Step 3 — detect topology

Same. The script's output is shown either way.

### Step 4 — scan signals (retrofit only)

| Mode         | Behaviour                                                                 |
|--------------|---------------------------------------------------------------------------|
| hands-off    | Run the scan, summarise findings in 5–8 bullets, proceed.                 |
| interactive  | Run the scan, present findings, **wait** for the user to confirm: "did I find the right LLM call site?" before Step 5. |

If the scan returns ambiguous results (e.g., multiple system prompts,
multiple LLM call sites), **always** ask — regardless of mode. Picking
the wrong one costs the user real time.

### Step 5 — match archetype

| Mode         | Behaviour                                                                 |
|--------------|---------------------------------------------------------------------------|
| hands-off    | Pick one archetype. Tell the user which and why in one sentence; proceed. |
| interactive  | Present the top match + the runner-up if it's close, with a one-line tradeoff. **Wait** for the user to pick.|

If the matcher's top score is tied or genuinely close (your subjective
"50/50"), **always** ask — regardless of mode. Hard Rule 1 says no
hybrids; the user has to disambiguate.

### Step 6 — generate

| Mode         | Behaviour                                                                 |
|--------------|---------------------------------------------------------------------------|
| hands-off    | Render all templates, write all files, no progress check-in.              |
| interactive  | Render templates, show the user the generated `ARCHITECTURE.md` and `IMPLEMENTATION_PLAN.md` first, **wait** for go-ahead before writing scaffolds and installing the symlink. |

### Step 7 — install

Same in both modes — this is a deterministic shell operation.

### Step 8 — report

Same in both modes. Hands-off mode's report is *richer*: it explicitly
lists everything that was inferred or chosen-by-default, so the user
can correct it on a regenerate.

---

## Threading the choice into the child skill

The child skill inherits the mode via `{{AUTONOMY}}`. Its `SKILL.md`
template includes a parallel "Step 0" that asks the user *whose
behavior* they want — same prompt, same defaults — but the **default**
for the child matches the parent's choice. So a user who picked
hands-off at the meta level isn't pestered when they invoke the child.

The child skill's "actions" are different from the meta's:

- the child applies the retrofit edits (or doesn't, in dry-run mode)
- the child runs the ingestion script (or prints the command)
- the child runs the verification recipe (or prints the steps)

Hands-off child = "do all of the above end-to-end." Interactive child
= confirm before each.

---

## What the user can change mid-run

In **interactive** mode, the user can interrupt at any step with:

- "actually, change the archetype to X" → re-run Step 5 with their
  choice; subsequent steps regenerate
- "use Python instead" → re-run Step 6 with the SDK override
- "skip the scaffolds, just give me the plan" → write `ARCHITECTURE.md`
  and `IMPLEMENTATION_PLAN.md`, skip the rest

In **hands-off** mode, the user can re-run with overrides on the
command line / prompt:

> "Regenerate `contextual-agent-generator--project-1` with archetype
> = personalized-chat, SDK = python."

The regenerate semantics (Step "Regenerate" in the main `SKILL.md`)
preserve `custom/` so any hand-tuning the user did between runs
survives.

---

## When to break out of the chosen mode

There are three situations where you should **always** ask, regardless
of mode:

1. **A hard rule is at risk of being violated.** E.g., the change set
   exceeds 10 files (Rule 3); the matched archetype isn't documented
   (Rule 1). Stop and ask.
2. **The user's interview answers contradict the scan.** E.g., they
   said "no existing context layer" but the scan found `pinecone-client`
   in `package.json`. Surface the conflict; let them resolve it.
3. **A secret-shaped value would be written to disk.** E.g., the scan
   accidentally surfaced a real API key. Redact, warn, and ask.

Hands-off does not mean *silent*; it means *fewer questions*, not
*zero questions when it matters*.
