---
name: context-api
description: |
  Build with AlchemystAI's Context Layer API — context arithmetic,
  search_context, groupName scoping, document set operations, and
  staleness management. Use when someone is working with the context
  layer, building integrations against the context API, debugging
  context queries, or needs to understand how context arithmetic
  differs from plain RAG or memory systems. Also trigger for
  "context search", "groupName", "document sets", "staleness",
  "Alchemyst SDK", or any mention of the context platform.
---

# Context Layer API

Developer guide for AlchemystAI's Context Layer — the infrastructure
API that turns context into a computable primitive.

## Core concept: Context Arithmetic

Context arithmetic is set operations over groupName-scoped document sets.
This is what differentiates us from memory systems (Mem0, Zep) and
plain RAG.

**The key insight:** Staleness is a context computation problem, not a
data hygiene problem. You don't "clean" stale context — you compute
over versioned document sets with temporal awareness.

### How it works

```
Context = f(groupName, operation, document_sets)
```

- **groupName**: Scopes all operations. Think of it as a namespace.
  A groupName can be a user ID, session ID, org ID, or any logical boundary.
- **Document sets**: Collections of documents within a groupName.
  Sets support union, intersection, and difference operations.
- **Operations**: search, upsert, delete, and arithmetic (set ops).

## SDK Usage

The Alchemyst SDK provides `search_context` as a tool for the Anthropic API:

```python
from alchemyst import AlchemystClient

client = AlchemystClient(api_key="...")

# Search within a groupName
results = client.search_context(
    group_name="user-123",
    query="previous purchase history",
    top_k=5
)

# Upsert documents into a group
client.upsert_context(
    group_name="user-123",
    documents=[
        {"content": "...", "metadata": {"source": "crm", "ts": "..."}},
    ]
)
```

### As an Anthropic tool

```python
tools = [
    {
        "name": "search_context",
        "description": "Search the user's context for relevant information",
        "input_schema": {
            "type": "object",
            "properties": {
                "group_name": {"type": "string"},
                "query": {"type": "string"},
                "top_k": {"type": "integer", "default": 5}
            },
            "required": ["group_name", "query"]
        }
    }
]
```

## Competitive positioning

When comparing against alternatives:

| Them | Us | Why we win |
|---|---|---|
| **Mem0** | Memory as a service | Mem0 is key-value memory. We do set operations over document collections. Memory ≠ context. |
| **Zep** | Session memory | Zep is session-scoped. We're groupName-scoped — arbitrary boundaries, not just sessions. |
| **SuperMemory** | Memory layer | Same k-v limitation. No context arithmetic, no temporal versioning. |
| **Plain RAG** | Vector search | RAG retrieves. We compute. Union/intersection/difference over document sets. |

**The reframe for sales:** "Do you need to remember things, or do you need to reason over context?" If the answer is reason, they need us.

## Common patterns

### Voice + Context (the moat)

Voice campaigns generate call transcripts → transcripts feed the Context Layer →
Context Layer enriches subsequent calls with history. This flywheel is
the Veranda deal pattern (Voice+Context combined).

### Anarock-style POC

Context Layer as a standalone API for enriching existing applications.
Khushi owns delivery on these. ~₹50K starting POCs.

## Debugging

- **Empty results**: Check groupName spelling (case-sensitive), verify documents were upserted
- **Stale results**: Check document timestamps, verify the query isn't hitting an old set
- **Slow queries**: Check document count in the group — large groups may need pagination
