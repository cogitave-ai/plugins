---
name: find-owner
description: >-
  Invoke whenever the question is WHO owns / is accountable for / should review /
  should be routed a node, area, repo, doc, standard, ADR, service, or request —
  e.g. "who owns X", "who do I ask about Y", "who reviews changes to Z", "which
  team is accountable here". Resolves ownership by combining the node's
  front-matter `owner` (cogitave/<team>), the estate.yaml role mapping, and the
  typed graph (get_related over forRole/appliesTo/partOf), then returns the
  concrete human or agent to route to. Read-only. Use this instead of guessing an
  owner from a path or a name.
allowed-tools: mcp__cogitave-core__docs_fetch, mcp__cogitave-core__get_related, mcp__cogitave-core__query_graph, mcp__cogitave-core__docs_search, Read, Grep, Glob
---

# Find Owner — resolve accountable ownership and route

## Purpose

Turn "who owns this?" into a **concrete routing target** (a `cogitave/<team>`, a
human CODEOWNER, or an accountable agent identity) backed by evidence, not a
guess. Ownership in the estate is explicit and layered: every node carries a
DocFX `owner` in front matter, `estate.yaml` maps repos to a `role`/owner, and
the graph encodes scope via `forRole`/`appliesTo`/`partOf`. This skill fuses
those three.

Invocation: `/cogitave-estate:find-owner`.

## When to use

- "Who owns / maintains / is accountable for <node|area|repo>?"
- "Who should review a change to <X>?" / "Who do I escalate to?"
- Before routing a question, an issue, or (in `cogitave-flow`) a Request to a
  team — resolve the accountable owner first.

## Ownership sources (resolve in this order)

1. **Front-matter `owner` (authoritative for a node).** `docs_fetch(uid)` and
   read `frontMatter.owner` — a `cogitave/<team>` handle (e.g. `cogitave/platform`,
   `cogitave/security`, `cogitave/ai`). This is the primary signal for any doc,
   standard, ADR, or lifecycle artifact.
2. **`estate.yaml` role mapping (authoritative for a repo/area).** For a repo or
   tier, resolve its `role` (`oss|marketing|platform|infra|docs|corp|ops`) and
   owning org/team from the estate manifest. On disk, `Read`/`Grep` the local
   `estate.yaml` (the single source for the estate); over MCP, fetch the
   corresponding area/Service node.
3. **Graph scope (who it is *for*, what governs it).** `get_related(uid,
   edgeTypes=["forRole","appliesTo","partOf"])` to find the role a node is scoped
   to, the standard/policy that governs it, and its parent area — each carries its
   own `owner`. For a structural query use `query_graph`, e.g.
   `MATCH (n {uid:$uid})-[:forRole]->(r) RETURN r`.
4. **CODEOWNERS (review routing).** Map the team to the concrete reviewers via the
   repo `CODEOWNERS` (the human gate). On disk, `Read`/`Grep` `CODEOWNERS`.

Precedence: the node's own `owner` wins for the node; fall back to the
repo/area `role` owner; use the graph to disambiguate scope and find the
governing/parent owner; use `CODEOWNERS` to name the human reviewer.

## MCP tools / resources this skill calls

- `docs_fetch(uid)` -> `frontMatter.owner`.
- `get_related(uid, edgeTypes=["forRole","appliesTo","partOf"])`.
- `query_graph(pattern)` for structural owner/scope lookups (bounded, read-only).
- `docs_search` to locate the node when only a topic/name is given.
- `Read` / `Grep` / `Glob` for local `estate.yaml` and `CODEOWNERS` when present.
- Resources: `cogitave://{type}/{id}`.

Scoped `mcp__cogitave-core__<tool>`. Read-only.

## Output format

1. **Owner** — the accountable `cogitave/<team>`, with the source that established
   it (front-matter `owner` / `estate.yaml` role / governing-node owner).
2. **Route to** — the concrete target: the team handle, and (if resolvable) the
   human CODEOWNER reviewers or the accountable agent identity.
3. **Evidence** — the UID(s) and file(s) consulted (front matter, `estate.yaml`
   line, edges traversed).
4. **Caveat** — if sources disagree or the node lacks an `owner`, say so and give
   the best fallback (parent area owner) rather than a guess.

## Examples

- *"Who owns the documentation standard?"* -> `docs_search` -> `docs_fetch` the
  Standard UID -> `frontMatter.owner: cogitave/platform` -> route to
  `cogitave/platform`; cite the UID.
- *"Who reviews changes to the agents/ tree?"* -> area owner from front matter
  (`cogitave/ai`) + `CODEOWNERS` entry for the path -> name reviewers.
- *"Who's accountable for this request?"* -> `docs_fetch` the
  `cogitave://request/{id}` node -> its `owner` field -> route there.

## Edge cases

- **No `owner` on the node:** climb `partOf` to the parent area and use its owner;
  flag the missing front matter as a docs-as-code gap.
- **Conflicting owners** (node vs. repo `role`): report both; node-level `owner`
  wins for the node, repo `role` for the repo.
- **Team -> human unresolved** (no local `CODEOWNERS`): return the team handle and
  say the human mapping needs the repo's `CODEOWNERS`.
- **Routing a change:** this skill only *identifies* the owner; opening the
  issue/PR is a propose-only action that belongs to `cogitave-flow`.
