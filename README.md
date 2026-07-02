# cogitave-ai/plugins — the Cogitave plugin marketplace

> The **public Claude Code plugin marketplace** for the Cogitave estate. It ships
> the agent-facing surface of **Cogitave Core** — the typed property graph that
> humans and agents query through the **same** model over MCP. The plugins are
> thin: they carry the skills, the read-only research subagent, and a `.mcp.json`
> that points at Core (the MCP server; see `core` ADR-0003). The intelligence
> lives in Core, not here.

This repo is OSS and lives in the `cogitave-ai` GitHub org. It is the **single
source** for the distributable plugins; estate repos consume them project-scoped
(pinned by git SHA at Day 0).

## What's in the marketplace

| Plugin | Surface | What it does |
|---|---|---|
| **`cogitave-estate`** | **READ** (discovery + query) | Tiered onboarding, the property-graph knowledge map, hybrid docs/graph search, and ownership routing. Read-only, least-privilege — it never proposes or writes. |
| **`cogitave-flow`** | **WRITE** (governed contribution) | Automates the canonical 7-stage [request lifecycle](https://cogitave.com) + docs-as-code. **Propose-only at Day 0**: opens issues/PRs and stages *draft* Request nodes; it never merges, applies, releases, or writes a protected branch. |

Both plugins are declared in
[`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json).

## Install

```text
# 1. add this marketplace
/plugin marketplace add cogitave-ai/plugins

# 2. install the read surface (most external agents start here)
/plugin install cogitave-estate@cogitave

# 3. optionally add the governed write surface
/plugin install cogitave-flow@cogitave
```

Project-scoped install (the estate pattern) enables the plugins in
`.claude/settings.json` instead:

```json
{
  "enabledPlugins": [
    "cogitave-estate@cogitave",
    "cogitave-flow@cogitave"
  ]
}
```

`cogitave/template-base` PINS the plugins for every new repo and commits the thin
`.mcp.json`; that is the only place repos couple to Core.

## Talking to Core (MCP)

Each plugin ships a thin
[`.mcp.json`](plugins/cogitave-estate/.mcp.json) declaring **one** server,
`cogitave-core` (type `http`, `requiresAuth: true`), reached through the
`cogitave-cloud` MCP gateway. Day-0 auth is an API key
(`COGITAVE_API_KEY`); OAuth 2.1 Resource-Server scopes are the documented target
(MCP spec 2025-11-25). Local agents may instead run Core as a **stdio** server
in-estate. Tools are scoped `mcp__cogitave-core__<tool>`:

- **Read:** `docs_search`, `docs_fetch`, `code_sample_search`, `get_related`,
  `get_learning_path`, `resolve_xref`, `query_graph`, `describe_schema`,
  `list_requests`, `get_request`, `get_dod`.
- **Propose-only (flow):** `request_intake`, `advance_stage` — open a GitHub
  issue/PR and stage a *draft* `Request` node; never mutate protected state.
- **Resources:** `cogitave://{type}/{id}`, including `cogitave://request/{id}`.

## Policy

Everything here runs under the org **managed policy** (`AGENTS.md`): English
only, least privilege, **no unapproved mutation**, human-in-the-loop on
consequence. `cogitave-estate` is read-only by construction; `cogitave-flow` is
propose-only by construction. Agents act under their **own identity** and only
use tools named in their grant.

## Day-0 honesty

These are **specs and scaffolds**. Nothing executes against a live estate yet:
the MCP endpoint URL is a placeholder to confirm at cutover, and versions are
omitted from `plugin.json` (Day-0 pin is the git SHA; semver moves to
`cogitave-ai/registry` later).

## Layout

```text
plugins/                              # this marketplace repo
├─ .claude-plugin/marketplace.json    # lists cogitave-estate + cogitave-flow
├─ README.md                          # this file
└─ plugins/
   ├─ cogitave-estate/                # READ surface
   │  ├─ .claude-plugin/plugin.json
   │  ├─ .mcp.json                    # -> cogitave-core
   │  ├─ agents/estate-researcher.md  # read-only research subagent
   │  └─ skills/
   │     ├─ onboard/SKILL.md
   │     ├─ knowledge-map/SKILL.md
   │     ├─ query/SKILL.md
   │     ├─ find-owner/SKILL.md
   │     └─ impact-map/SKILL.md
   └─ cogitave-flow/                  # WRITE surface (separate; propose-only)
```
