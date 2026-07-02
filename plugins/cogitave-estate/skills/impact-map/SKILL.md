---
name: impact-map
description: >-
  Invoke BEFORE changing any estate artifact -- a file, a UID, or a concept --
  i.e. "what else must change with this", "where is this value restated", "what
  is the blast radius of this edit". Produces the AFFECTED-ARTIFACT CHECKLIST
  from two passes: a graph pass (reverse xref + dependsOn traversal, depth<=4,
  plus resolve_xref backlinks) for LINKED references, and a fact pass (the fact
  registry data/facts.yaml + the fact-drift.py scanner) for UNLINKED prose
  restatements the graph cannot see. Read-only -- it never edits anything
  itself. Complements knowledge-map (orientation before a journey): impact-map
  is pre-change propagation.
allowed-tools: mcp__cogitave-core__query_graph, mcp__cogitave-core__get_related, mcp__cogitave-core__resolve_xref, mcp__cogitave-core__docs_search, Read, Grep, Bash(python3:*)
---

# Impact Map -- the affected-artifact checklist before a change

## Purpose

The estate is a growing **second brain**: when a change semantically touches
one place, the map must surface every related place that has to move with it.
The typed graph already catches **linked** references (`xref`, `dependsOn`) --
but two adversarial audits found 21 real defects, and nearly all were a
load-bearing fact **restated in unlinked prose** that drifted after the
canonical value changed (an ADR restated the SLO ladder wrong; ci-cd said
`>=2` reviewers where the owner says `>=1`; "17 node types" survived after the
schema went to 18). The applied lesson is: **the ADR decides, the standard
carries the number, everything else points.** This skill operationalizes that
lesson *before* the edit: a graph pass for everything that points, a fact pass
for everything that restates.

Invocation: `/cogitave-estate:impact-map <file | uid | concept>`.

## When to use

- Before editing any doc/standard/ADR/schema that other artifacts reference or
  restate -- especially anything carrying a **number, tier, threshold, count,
  or ruling** (SLO tiers, reviewer minimums, node-type counts, defaults).
- Before renaming or moving a UID/file (backlink inventory first).
- As pre-flight for lifecycle **stage 3 (plan)**: the checklist is the raw
  input to the blast-radius set.

Use `knowledge-map` when the question is about **structure**, `query` when it
is about **content**, and this skill when you are **about to change something**.

## How it works

1. **Resolve the target.** A file path -> its `uid` (front matter or
   `resolve_xref`); a concept -> `docs_search` to find the owning node, then
   confirm the single canonical UID before walking anything.
2. **Graph pass (linked references).** Walk the graph *backwards* from the
   target, bounded profile only:
   - `query_graph`: `MATCH (n)-[:xref|dependsOn*1..4]->(t) WHERE t.uid =
     $target RETURN DISTINCT n.uid, n.title, labels(n)` -- reverse `xref` +
     `dependsOn`, depth capped at `*1..4`, small `limit`.
   - `resolve_xref(uid=$target)` -- backlinks and any `supersededBy` pointer.
   - `get_related(uid=$target, direction="in", depth=1)` -- the immediate
     typed neighborhood for the checklist's "why affected" column.
3. **Fact pass (unlinked restatements).** Read the fact registry
   `cogitave/standards/data/facts.yaml`. A fact is touched when the target file
   matches the fact's `owner` path **or** the planned edit matches the fact's
   `pattern` regex. For every touched fact:
   - add **every file in the fact's `scope`** (the files the scanner watches)
     to the checklist -- these are exactly the places prose restatements hide;
   - instruct the caller to run, **after the edit**:
     `python3 cogitave/standards/tools/fact-drift.py --fact <id>` (add `--json`
     for machine-readable output). The scanner is deterministic and read-only;
     a **non-zero exit means a restatement still drifts** from the owner.
   - **COUNTER-class facts** (e.g. `core-node-types`, the standards count) are
     verified by **recounting the authoritative set**, never by matching a
     restated literal -- the literal is only correct until the set grows.
   Registered facts include `slo-tiers`, `burn-rate-ladder`, `prod-reviewers`,
   `core-node-types`, `trunk-based`, `english-only`; the registry file is
   authoritative, not this list.
4. **Lifecycle tie.** If the change is **design-class** (new public surface,
   cross-cutting, breaking, or security-relevant), do not edit ad hoc: route it
   through the request lifecycle (`cogitave/agents/lifecycle/LIFECYCLE.md`) and
   hand this checklist to `/cogitave-flow:plan` as the stage-3 blast-radius
   input; stage 7 (doc-update) closes the loop with the graph reindex.

## MCP tools / resources this skill calls

- `query_graph(pattern, limit)` -- the reverse `xref`/`dependsOn` walk, bounded
  read-only profile (`*1..4`, hard row cap).
- `resolve_xref(uid)` -- backlinks + `supersededBy` for the target.
- `get_related(uid, direction="in", depth=1)` -- typed inbound neighborhood.
- `docs_search(query)` -- only to resolve a *concept* to its owning UID.
- Local, non-MCP: `Read`/`Grep` on `cogitave/standards/data/facts.yaml`;
  `python3 cogitave/standards/tools/fact-drift.py` (stdlib-only, read-only).

Scoped `mcp__cogitave-core__<tool>`. **Read-only** -- this skill never applies
an edit; it tells the caller what the edit must also touch.

## Output format

The **AFFECTED-ARTIFACT CHECKLIST**, in three parts:

1. **Checklist table** -- one row per affected artifact:

   | Artifact | Why affected | Action |
   |---|---|---|
   | `standards/docs/standards/ci-cd.md` | scope of fact `prod-reviewers` (restates the reviewer minimum) | update restatement or replace with `<xref:...>`; re-run scanner |
   | `cogitave.core.architecture` | reverse `xref` -> target (linked) | verify the pointer still resolves; no restated value to fix |

2. **Fact verification** -- the exact command(s) to run after the edit:
   `python3 cogitave/standards/tools/fact-drift.py --fact <id>` per touched
   fact (non-zero exit = drift remains), plus the recount instruction for any
   COUNTER-class fact.
3. **Routing** -- direct edit (non-design-class) vs. request lifecycle
   (design-class), stated explicitly with the reason.

Prefer the strongest action available: **replace a restatement with a pointer**
(`<xref:uid>` / include) over hand-syncing the copy.

## Examples

- *"I am changing the SLO tiers in reliability.md section 2.1."* -> target file
  is the `owner` of fact `slo-tiers` -> checklist = the fact's full `scope`
  (every doc that ever restated the ladder, e.g. the ADR and blueprint
  restatements the audits caught) + graph-pass backlinks -> run
  `fact-drift.py --fact slo-tiers` after the edit.
- *"I am adding a node type under core/schema/nodes/."* -> COUNTER-class fact
  `core-node-types`: recount the schema set, then fix every prose count in
  scope; graph pass on `cogitave.core.schema` lists the linked dependents.
- *"I am renaming this UID."* -> `resolve_xref` backlinks + reverse `xref`
  rows; every inbound pointer is a checklist row with action "update xref".

## Edge cases

- **Target not in the graph (new file):** an empty graph pass is *not* "no
  impact" -- run the fact pass and a `docs_search` for concept-level mentions
  before concluding the blast radius is empty.
- **Scope file already points instead of restating:** keep the row, action =
  "verify the xref resolves" -- pointers are the desired end state.
- **Unbounded ask:** never walk `*`; keep depth `*1..4` and cap `limit`, per
  the bounded read-only profile.
- **Volatile counters:** never assert a COUNTER-class value from prose; count
  the authoritative set at answer time and say which set you counted.
- **Day-0:** the Core MCP endpoint is a **placeholder until cutover** -- the
  graph pass then degrades to `Grep` over the estate mirror for `uid:` /
  `<xref:uid>` mentions of the target (say so in the output). The **fact pass
  works TODAY**: the registry and scanner are local files, deterministic and
  read-only.
