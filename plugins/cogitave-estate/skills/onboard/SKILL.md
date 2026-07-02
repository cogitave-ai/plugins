---
name: onboard
description: >-
  Run this FIRST, before any other estate work, whenever an agent (or a human's
  agent) begins a session against the Cogitave estate, lacks context on the
  managed policy, or asks "how do I get started / what are the rules / how is
  this organized". Performs tiered onboarding: reads the managed-policy floor
  (AGENTS.md) and the llms.txt index, calls describe_schema for the node/edge
  vocabulary, loads the Level-2 UID references (standards, lifecycle), and
  verifies the caller's capability grant before any action. Do NOT skip onto
  query/contribution work until onboard has confirmed preconditions and handed
  off. Read-only.
allowed-tools: mcp__cogitave-core__describe_schema, mcp__cogitave-core__docs_fetch, mcp__cogitave-core__docs_search, mcp__cogitave-core__get_related, mcp__cogitave-core__resolve_xref, Read
---

# Onboard — tiered entry into the Cogitave estate

## Purpose

Bring an agent from zero context to "safe to act" in the **minimum** tokens, by
**progressive disclosure**: load the policy floor and the schema vocabulary
first, pull deeper references only on demand, and confirm the caller is operating
inside its capability grant before handing off to any other skill. Cogitave Core
is the single model humans and agents both query; onboarding is the same model's
front door.

Invocation: `/cogitave-estate:onboard`.

## When to use

- The very first turn of any session that will touch the estate.
- The agent has no loaded context on the managed policy, the schema, or its grant.
- Someone asks "how do I start", "what are the rules here", "how is this org
  structured", or "what can I do".

Do **not** re-run it once preconditions are confirmed in-session.

## Tiered model (load in order, stop early)

**Level 0 — Policy floor (always).** The nearest `AGENTS.md` is the managed
policy and the *floor* every sub-tree inherits. Read it before anything else:
English only, Conventional Commits, signed, docs-as-code, least privilege, **no
unapproved mutation**, human-in-the-loop on consequence. If a local `AGENTS.md`
exists on disk, `Read` it; otherwise fetch the org policy node by UID:

- `docs_fetch(uid="cogitave.agents.overview")` for the operational layer, and
  resolve the policy doc via `resolve_xref` if a UID is referenced.

**Level 1 — Orientation index (always).** Fetch the `llms.txt` estate index
(the companion surface over the same catalog; see the MCP interface §4 companion
surfaces) to get the map of top-level areas without dumping content. Then call
`describe_schema()` once to load the **closed vocabulary** — node labels and the
typed edges (`partOf`, `dependsOn`, `xref`, `appliesTo`, `forRole`,
`teachesSkill`, `supersededBy`, `implementedBy`, `derivedFrom`) — so you can plan
multi-hop queries instead of dumping the estate. (For a rendered map, hand off to
`/cogitave-estate:knowledge-map`.)

**Level 2 — Targeted references (on demand only).** Pull the specific UID
references the task needs — never the whole standards tree. Common L2 anchors:

- Standards index and the standards the task touches (commits-versioning,
  documentation, authorization, security, observability, ai-agent-engineering).
- The request lifecycle, by UID `cogitave.agents.lifecycle` (the 7-stage
  process) and its Definition of Done `cogitave.agents.definition-of-done` — load
  these only if the session may contribute (then it belongs to `cogitave-flow`).
- The agent identity & capability model, UID
  `cogitave.agents.identity.capabilities`.

Use `docs_search` to find the right UID, `docs_fetch` to read it, `get_related`
to expand one hop.

**Level 3 — Capability grant (gate before acting).** Confirm the caller's
least-privilege grant covers the intended work. Per the identity model an agent
acts under **its own identity** and may only use tools named in its grant.
`cogitave-estate` is **read-only** — if the session needs to propose a change,
that is a *different* grant and the `cogitave-flow` plugin; do **not** work around
the boundary. State the grant you are operating under before handing off.

## MCP tools / resources this skill calls

| Step | Tool / resource |
|---|---|
| L0 policy | local `AGENTS.md` via `Read`; `docs_fetch`; `resolve_xref` |
| L1 index | `llms.txt` companion surface; `describe_schema()` |
| L2 refs | `docs_search` -> `docs_fetch` -> `get_related` |
| Resources | `cogitave://{type}/{id}` (e.g. `cogitave://doc/cogitave.agents.lifecycle`) |

All calls are scoped `mcp__cogitave-core__<tool>`. None mutate anything.

## Output format

Return a compact onboarding brief, not a content dump:

1. **Policy floor** — the 7 non-negotiables, one line each (cite `AGENTS.md`).
2. **Schema** — node labels + the edge types from `describe_schema` (one line).
3. **Map** — top-level estate areas from `llms.txt` (bullets, UID per area).
4. **Grant** — the read-only grant in effect; what is in/out of scope.
5. **Next** — the single best next skill to invoke
   (`knowledge-map` / `query` / `find-owner`, or `cogitave-flow` for writes).

## Examples

- *"I'm starting a review of the docs standard."* -> L0 floor; `describe_schema`;
  `docs_search("documentation standard")` -> `docs_fetch` the UID; state
  read-only grant; hand off to `/cogitave-estate:query`.
- *"I want to propose a change."* -> L0 floor; note this needs a **propose**
  grant, out of estate scope; hand off to `cogitave-flow` (lifecycle intake).

## Edge cases

- **No local `AGENTS.md`** (plugin installed in a bare repo): fetch the policy
  node over MCP; never assume the floor is absent.
- **MCP unreachable / unauthenticated:** report that `COGITAVE_API_KEY` (or the
  gateway/OAuth handshake) is missing; do not proceed to act blind.
- **Caller asks to mutate:** stop. Read-only grant; route to `cogitave-flow`.
- **Day-0:** endpoints are placeholders; if `describe_schema` is unavailable,
  say so and proceed with the policy floor only.
