# Alchemyst Patterns — SDK reference distilled from the platform docs

Source: <https://getalchemystai.com/docs/llms-full.txt>. This file
captures the SDK surface, `groupName` design rules, and verification
recipes that the matched archetype's plan plugs into. Read this once
during Step 5; the child skill's `IMPLEMENTATION_PLAN.md` cites
specific sections.

---

## Core concept: context arithmetic

Alchemyst is **not** a vector DB and **not** a memory library. It's a
context layer where every operation is scoped to a `groupName` and
documents inside a group support set operations (union, intersection,
difference) plus semantic search. The mental model:

```
Final Context = (Semantic Matches)
              ∩ (groupName Scope)
              ∩ (Metadata Filters)
              − (Deduplicated / Superseded)
              → rank → top-K
```

**Implication for agent design:** the answer to "what does my agent
see right now?" is a `groupName` + filter expression, not a vector
similarity score. Design the `groupName` *first*; everything else
follows.

---

## groupName design

The canonical shape is a **3-layer hierarchy**, each layer answering
one question:

| Layer    | Question it answers              | Examples                                  |
|----------|----------------------------------|-------------------------------------------|
| domain   | what kind of context is this?    | `"engineering"`, `"support"`, `"memory"`  |
| category | which slice of the domain?       | `"backend"`, `"product-x"`, session ID    |
| specific | which artefact / boundary?       | `"auth"`, ticket type, user ID            |

### Common shapes by archetype

| Archetype                      | groupName                                       |
|--------------------------------|-------------------------------------------------|
| RAG knowledge base             | `["domain", "category", "subcategory"]`         |
| Agent + persistent memory      | `["memory", session_id]` for memory; `["docs", category]` for retrieval |
| Personalized chat              | `["user", user_id, "profile"]` for profile; `["user", user_id, "history"]` for past turns |
| Voice + context flywheel       | `["calls", customer_id, call_id]` for transcripts; `["calls", customer_id, "summary"]` for distilled history |
| Multi-tenant SaaS              | `["org", org_id, domain]` then category/specific underneath |

### Anti-patterns

- **Flat keys**: `["eng_backend_auth_jwt_v2"]` — defeats the hierarchy.
  Use 3 layers, not one mega-key.
- **Over-nesting**: `["org", id, "domain", "cat", "sub", "leaf"]` —
  more than 5 layers fragments retrieval and the user can't remember
  the schema.
- **Mixing identity and content**: `["user-123-product-x"]` — keep
  identity (the user) and content type (the product docs) in separate
  layers so you can union them at query time.

---

## SDK surface

### Initialization

**TypeScript:**
```typescript
import Alchemyst from '@alchemyst-ai/sdk';

const client = new Alchemyst({
  apiKey: process.env.ALCHEMYST_AI_API_KEY,
});
```

**Python:**
```python
from alchemyst import Alchemyst
import os

client = Alchemyst(api_key=os.environ["ALCHEMYST_AI_API_KEY"])
```

Auth is `Authorization: Bearer <ALCHEMYST_AI_API_KEY>`. Get the key
from `platform.getalchemystai.com → Settings → API Keys`. Store in
`.env`, **never** commit.

### Ingest

| Method                          | When to use                                  |
|---------------------------------|----------------------------------------------|
| `client.v1.context.add`         | Sync, ≤100 docs/call. Use for low-volume / one-shot |
| `client.v1.context.addAsync` *(TS)* / `client.v1.context.add_async` *(Py)* | Bulk / scheduled ingestion. Returns a `jobId` you poll |

Each document is `{ content, metadata }`. `metadata.groupName` is the
hierarchy; `metadata.fileName` is used for dedup; everything else is
yours to filter on.

```typescript
await client.v1.context.add({
  documents: [{
    content: "...",
    metadata: {
      fileName: "auth-guide.md",
      groupName: ["engineering", "backend", "auth"],
      version: "v2",
    }
  }]
});
```

### Search

```typescript
const results = await client.v1.context.search({
  query: "how do we rotate JWT refresh tokens?",
  groupName: ["engineering", "backend", "auth"],
  metadata: { version: "v2" },
  similarity_threshold: 0.6,
  limit: 5,
});
```

`similarity_threshold` defaults loose; `0.5–0.6` is a safe starting
point for production. Always set `limit` — unbounded retrieval blows
your token budget.

### Memory (chat history)

```typescript
await client.v1.context.memory.add({
  sessionId,
  role: "user",
  content: "...",
  metadata: { ts: new Date().toISOString() },
});

const turns = await client.v1.context.memory.list({ sessionId, limit: 20 });
```

The memory endpoints are a thin convenience around `add`/`search` with
a `["memory", sessionId]` group and a `role` field. If you need
cross-session profiling, store the *distilled* profile under a
different group (e.g., `["user", userId, "profile"]`) — don't replay
raw memory across sessions.

### Updates: delete-then-add

There is no in-place update. To replace a document:

```typescript
const existing = await client.v1.context.search({ metadata: { fileName } });
if (existing.documents.length) {
  await client.v1.context.delete({ ids: [existing.documents[0].id] });
}
await client.v1.context.add({ documents: [{ content, metadata: { fileName } }] });
```

This is the fix for `409 Conflict` errors on re-ingestion.

### Async ingestion + polling

```typescript
const { jobId } = await client.v1.context.addAsync({ documents: batch });
let state = "pending";
while (state !== "completed" && state !== "failed") {
  await new Promise(r => setTimeout(r, 1000));
  const s = await client.v1.context.getAsyncStatus(jobId);
  state = s.state;
}
```

Use async when:

- batch > 100 docs (sync limit)
- ingestion is on a schedule and the caller doesn't need to block
- you need resilience to transient failures (the queue retries)

### Observability

`client.v1.context.traces.list` returns the audit trail of which
documents were retrieved for which queries. Wire this into the runbook
when the agent gets a "why did you cite X?" debug request.

---

## Limits & gotchas

| Limit                          | Value             | Implication                              |
|--------------------------------|-------------------|------------------------------------------|
| Max file size                  | 50 MB / doc       | Pre-chunk large PDFs                     |
| Max batch size (sync)          | 100 docs / call   | Use async above this                     |
| Max metadata fields            | 20 keys / doc     | Don't dump the whole record into metadata|
| Indexing throughput            | ~120 docs/sec     | A 100k-doc ingest is ~15 minutes         |
| Rate limit                     | 1000 req/min      | Add backoff on the search path           |

| Status | Cause                          | Fix                                       |
|--------|--------------------------------|-------------------------------------------|
| 409    | `fileName` already exists      | Delete-then-add                           |
| 401    | bad / missing API key          | Re-check `.env`, verify key in platform   |
| 429    | rate limit                     | Exponential backoff; `addAsync` for bulk  |
| 422    | parsing failed                 | Validate `fileType` matches actual content|

---

## LLM integration

### Anthropic (tool use)

Expose `search_context` as a tool the model can call mid-conversation.

```python
tools = [{
    "name": "search_context",
    "description": "Search the user's organizational context for documents relevant to the question. Use whenever the answer would benefit from internal documents, past conversations, or org-specific knowledge.",
    "input_schema": {
        "type": "object",
        "properties": {
            "query": {"type": "string"},
            "groupName": {"type": "array", "items": {"type": "string"}},
            "limit": {"type": "integer", "default": 5},
        },
        "required": ["query", "groupName"],
    },
}]
```

When the model calls it, run the actual `client.v1.context.search` and
return `tool_result` with the documents inline.

### OpenAI (function calling)

```python
functions = [{
    "type": "function",
    "function": {
        "name": "search_context",
        "description": "...",
        "parameters": {...},  # same shape as Anthropic input_schema
    }
}]
```

### Inline retrieval (simpler, less powerful)

If the agent doesn't need to choose *whether* to retrieve — it always
should — skip tool use and prepend retrieval to every call:

```python
ctx = client.v1.context.search(query=user_msg, groupName=GROUP, limit=5)
system = SYSTEM_PROMPT + "\n\nContext:\n" + "\n---\n".join(d.content for d in ctx.documents)
```

This is what most retrofit minimum-deltas land on (Hard Rule 3): one
`search_context` call before the LLM call, plus a system-prompt
sentence saying "use the provided context."

---

## Verification recipes

The child skill's `RUNBOOK.md` carries archetype-specific verification
steps. The **universal** ones — every plan must include them — are:

1. **API key reachable**

   ```python
   client.v1.context.view()  # should not 401
   ```

2. **groupName round-trips a fixture**

   ```python
   client.v1.context.add(documents=[{
       "content": "FIXTURE_<uuid>",
       "metadata": {"groupName": TEST_GROUP, "fileName": f"fixture-{uuid}.txt"},
   }])
   results = client.v1.context.search(query="FIXTURE_<uuid>", groupName=TEST_GROUP)
   assert any("FIXTURE_<uuid>" in d.content for d in results.documents)
   ```

3. **End-to-end: search returns the fixture in tool-use loop**

   - call the LLM with the `search_context` tool
   - prompt it with a question only answerable via the fixture
   - confirm the model invoked the tool and the answer cites the
     fixture content

If step 3 fails, the system-prompt edit is wrong — the model isn't
reaching for the tool. Tweak the description until it does.
