---
name: knowledge-map
description: >-
  Invoke whenever an agent needs to UNDERSTAND THE SHAPE of the Cogitave estate
  before querying it — i.e. "what node types exist", "how are things connected",
  "what edges can I traverse", "what does the graph schema look like", or before
  planning any multi-hop query. Renders the property-graph vocabulary from
  describe_schema (+ a small query_graph probe): node labels, the typed edges
  partOf/dependsOn/xref/appliesTo/forRole/teachesSkill/supersededBy/implementedBy/derivedFrom,
  per-type constraints, and moniker axes — so agents plan precise traversals
  instead of dumping content. Read-only. Use this, not docs_search, when the
  question is about STRUCTURE rather than content.
allowed-tools: mcp__cogitave-core__describe_schema, mcp__cogitave-core__query_graph, mcp__cogitave-core__get_related
---

# Knowledge Map — render the property-graph schema

## Purpose

Give the agent a **map before a journey**. Cogitave Core is a typed property
graph; the cheapest way to answer almost any estate question is to traverse it
with intent. This skill materializes the **closed vocabulary** — node labels,
typed edges, constraints, monikers — so the agent can compose a targeted
`query_graph` / `get_related` plan rather than retrieving and skimming documents.

Invocation: `/cogitave-estate:knowledge-map`.

## When to use

- Right after `onboard`, when the agent needs the schema to plan work.
- Any "how is X connected to Y", "what links to this", "what types exist",
  "what can I traverse from a Standard / ADR / Agent / Request" question.
- Before writing a `query_graph` pattern, to confirm labels/edges are in the
  closed vocabulary (an unknown label is rejected server-side).

Use `query` (not this) when the user wants the **content** of nodes.

## How it works

1. **Vocabulary.** Call `describe_schema()` (no `type` arg) to get the full map:
   `nodes` (labels + per-type required attributes), `edges` (the typed edge
   catalog), and `monikers` (version axes). To zoom one label, pass
   `describe_schema(type="ADR")`.
2. **Probe (optional, bounded).** To show the schema is *live*, run one small
   `query_graph` against the **bounded read-only profile** — allowlisted labels,
   depth `*1..4`, `limit` small — e.g. count edges by type, or list the labels a
   given node connects to. Never use this to dump the estate.
3. **Neighborhood example.** For a concrete anchor, call `get_related(uid=...,
   depth=1)` to illustrate one real typed neighborhood.

## The closed edge vocabulary (what you may traverse)

| Edge | Meaning | Typical use |
|---|---|---|
| `partOf` | containment / hierarchy | Unit `partOf` Module; Doc `partOf` area |
| `dependsOn` | prerequisite / dependency | learning prereqs; service deps |
| `xref` | cross-reference | doc-to-doc citation |
| `appliesTo` | a standard/policy governs a target | Standard `appliesTo` area/repo |
| `forRole` | audience / role scoping | Doc `forRole` platform/security |
| `teachesSkill` | a Unit teaches a Skill | learning paths |
| `supersededBy` | deprecation pointer | demote superseded nodes |
| `implementedBy` | spec -> implementation | ADR/spec `implementedBy` code/agent |
| `derivedFrom` | provenance | derived/generated artifacts |

Node labels include (per `describe_schema`, not hard-coded here):
`Doc`, `Article`, `Unit`, `Module`, `LearningPath`, `Skill`, `ADR`, `Standard`,
`Service`, `Agent`, `Request`, and the area/product nodes. **Always read the live
schema** — the server is authoritative; this table is orientation.

## MCP tools / resources this skill calls

- `describe_schema()` — primary; the closed node/edge vocabulary + monikers.
- `query_graph(pattern, limit)` — optional, bounded structural probe only.
- `get_related(uid, depth=1)` — one concrete typed neighborhood.
- Resources: `cogitave://{type}/{id}` for any node it names.

Scoped `mcp__cogitave-core__<tool>`. Read-only; `query_graph` rejects any
mutating/DDL clause at parse time.

## Output format

A compact, planning-oriented map:

1. **Node labels** — bulleted, with the 1-2 key attributes each requires.
2. **Edge catalog** — the table above, filtered to what the schema returns.
3. **Monikers** — version axes that scope a query (e.g. `>=yuva-2.0`).
4. **Traversal recipes** — 2-3 ready `query_graph`/`get_related` patterns for the
   user's intent (e.g. "Standards that `appliesTo` core", "ADRs `implementedBy`
   an Agent"). Hand these to `/cogitave-estate:query` to execute.

## Examples

- *"What governs the core service?"* -> `describe_schema`; recipe:
  `MATCH (s:Standard)-[:appliesTo]->(t {uid:'cogitave.core...'}) RETURN s` via
  `query_graph`.
- *"Show me what an ADR connects to."* -> `describe_schema(type="ADR")` +
  `get_related(uid=<adr-uid>, depth=1)`.

## Edge cases

- **Unknown label/edge requested:** name the closed vocabulary; the server
  rejects anything outside it.
- **Unbounded traversal asked for:** refuse `*`; rewrite as `*1..4` and cap
  `limit`. Suggest faceting instead of dumping.
- **Day-0:** if `describe_schema` is a placeholder, present the documented closed
  vocabulary above and flag that the live schema is pending cutover.
