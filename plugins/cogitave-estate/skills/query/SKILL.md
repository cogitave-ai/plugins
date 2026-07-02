---
name: query
description: >-
  Invoke for ANY question whose answer is content that lives in the Cogitave
  estate — "where are the docs on X", "what does standard/ADR Y say", "find code
  samples for Z", "what is related to this node", "resolve this xref/UID", "which
  standards apply to area W". The front door to Cogitave Core's hybrid retrieval:
  docs_search (BM25 + vector + graph rerank), docs_fetch, code_sample_search,
  get_related, resolve_xref, and the bounded query_graph. Uses PROGRESSIVE
  DISCLOSURE — metadata/snippets first, then UID references, then full content
  only when needed — to answer in minimum tokens. Read-only; stays inside the
  read-only grant and never proposes a change.
allowed-tools: mcp__cogitave-core__docs_search, mcp__cogitave-core__docs_fetch, mcp__cogitave-core__code_sample_search, mcp__cogitave-core__get_related, mcp__cogitave-core__resolve_xref, mcp__cogitave-core__query_graph, mcp__cogitave-core__get_learning_path
---

# Query — hybrid retrieval over the estate

## Purpose

Answer estate questions against the **one** query layer humans and agents share:
hybrid retrieval (lexical BM25 + dense vectors fused by reciprocal rank fusion,
then graph-aware rerank). This skill is a disciplined front-end over those tools
that **discloses progressively** — it never dumps a tree when a snippet, a UID,
or a single fetch will do.

Invocation: `/cogitave-estate:query`.

## When to use

- Find/read docs, standards, ADRs, articles, learning units.
- Find compile-checked **code samples** by reference.
- Expand a node's typed neighborhood, or resolve a `<xref:uid>` / `@uid`.
- Structural lookups over the graph (delegates the *map* to `knowledge-map`).

Use `knowledge-map` first when the question is about **structure**; use
`find-owner` when the question is **who owns this**.

## Progressive disclosure (the core discipline)

Answer in the **cheapest** stage that satisfies the question; escalate only if it
does not:

1. **Metadata / snippets.** `docs_search` -> ranked `{uid, title, uri, snippet,
   score, signals}` + `facets`. Often the snippet *is* the answer; cite the UID.
2. **UID references.** Hand back the UIDs / `cogitave://{type}/{id}` URIs and the
   one-hop relations (`get_related`, `depth=1`) so the caller can pull more only
   if needed. Resolve any indirect reference with `resolve_xref` (moniker-aware;
   reports `supersededBy`).
3. **Full content.** Only when the task needs the body, `docs_fetch(uid)` the
   specific node(s). Pass `moniker` / `locale` to get the version-correct node.

Never fetch a whole area to answer a narrow question; that is what `facets` and
`query_graph` filters are for.

## Tool selection

| Intent | Tool |
|---|---|
| Find docs/standards/ADRs by topic | `docs_search(query, types?, product?, moniker?, topK?)` |
| Read one node in full | `docs_fetch(uid, moniker?, locale?)` |
| Find code-by-reference samples | `code_sample_search(query, language?, product?)` |
| Expand typed neighbors of a node | `get_related(uid, edgeTypes?, direction?, depth<=4)` |
| Resolve `<xref:uid>` / `@uid` | `resolve_xref(uid, moniker?)` |
| Structural / multi-hop pattern | `query_graph(pattern, params?, limit<=1000)` |
| Prereq-ordered learning toward a skill | `get_learning_path(targetSkill, knownSkills?)` |

`query_graph` runs only the **bounded read-only profile**: no mutation/DDL,
allowlisted node/edge labels (the 9 closed edges), depth capped at `*1..4`, hard
row cap (`limit`, with `truncated`), per-query timeout. A violation returns a
tool error (`isError: true`) so you can self-correct — read the reason and fix
the pattern; do not retry blindly.

All calls scoped `mcp__cogitave-core__<tool>`. **Read-only** — if the user wants
to change something, stop and route to `cogitave-flow`.

## Output format

1. **Answer** — direct, grounded in retrieved content.
2. **Sources** — UID + `cogitave://{type}/{id}` for each node used; note
   `moniker`/`lastModified` when version matters and `supersededBy` if stale.
3. **Confidence / gaps** — if `score` is low or `facets` show the answer spans
   several nodes, say so and offer the next narrowing query.
4. **Next hop (optional)** — a ready `get_related` / `query_graph` for follow-up.

Prefer citing UIDs over pasting long bodies. Quote only the load-bearing lines.

## Examples

- *"What does the documentation standard require for code blocks?"* ->
  `docs_search("documentation standard code blocks", types=["Standard"])` ->
  `docs_fetch` the top UID -> quote the relevant rule + cite UID.
- *"Show Rust examples of the MCP server tools."* ->
  `code_sample_search("MCP server tools", language="rust")` -> return samples +
  `sourceUri`.
- *"What's related to the request lifecycle doc?"* ->
  `get_related(uid="cogitave.agents.lifecycle", depth=1)` -> list typed edges.
- *"Resolve @cogitave.core.query."* -> `resolve_xref` -> current URI + title.

## Edge cases

- **Ambiguous query:** return top candidates with `facets` and ask which area,
  rather than fetching all.
- **`truncated: true`:** tighten the pattern / lower scope; report truncation.
- **Superseded node:** surface `supersededBy` and prefer the canonical successor.
- **Write request:** out of scope — read-only grant; hand off to `cogitave-flow`.
- **Day-0:** endpoints may be placeholders; report unreachable retrieval rather
  than fabricating an answer.
