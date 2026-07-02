---
name: implement
description: >-
  Use this to actually DO the work once a Request is ready to build — non-design
  changes after plan approval, or design-class changes after the RFC/ADR is
  Accepted. "Implement it", "scaffold the branch", "write the code for REQ-...".
  This automates Stage 5 (implement): it scaffolds on a feature branch strictly
  within the task's least-privilege grant, makes signed Conventional Commits in
  English, and opens a draft PR linked to the Request. It NEVER merges, applies,
  releases, or writes a protected branch — the consequential action is held for
  the review gate. Do NOT use it to plan, to author decisions, or to merge.
allowed-tools:
  - mcp__cogitave-core__get_request
  - mcp__cogitave-core__code_sample_search
  - mcp__cogitave-core__docs_fetch
  - mcp__cogitave-core__query_graph
  - mcp__cogitave-core__advance_stage
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
---

# Stage 5 - Implement (`/cogitave-flow:implement`)

Automates **Stage 5 (implement)** of the
[Request Lifecycle](../../../../../../cogitave/agents/lifecycle/LIFECYCLE.md#5-implement).
The work is done on a branch, inside the per-task scope from Stage 3, under the
floor in [`AGENTS.md`](../../../../../../AGENTS.md). This skill **proposes**; it
never commits the consequential act.

## Purpose

Produce a **feature branch**, **signed Conventional Commits** (English only), and
an **open draft PR** linked to the Request — all strictly **inside the task
grant**.

## When to use

- Non-design-class Request advanced `plan -> implement`.
- Design-class Request whose RFC/ADR is **Accepted** (`document -> implement`).
- Do **not** use to plan, to author decisions, or to merge/apply.

## Gate this skill enforces

**Implement gate:** **inside grant** (no capability used beyond the Stage-3 task
scope; no grant broadened) **AND** **no protected-branch write / no apply** — the
consequential action is held for the human gate at review. Drift between granted
and effective authority is a control failure and must be alarmed, not worked
around.

## MCP tools & resources used

- `mcp__cogitave-core__get_request` - load the Request, the plan, and the
  per-task scopes.
- `mcp__cogitave-core__code_sample_search` - compile-checked reference snippets.
- `mcp__cogitave-core__docs_fetch` - fetch the authoritative API/contract docs.
- `mcp__cogitave-core__query_graph` - confirm edges/contracts the code must honor.
- `mcp__cogitave-core__advance_stage` - **PROPOSE-ONLY write.** Records the branch
  + draft PR link and proposes `implement -> review`. It does **not** merge,
  apply, release, or write a protected branch.
- Code itself is authored with the agent's normal sandbox tools (Write/Edit/Bash);
  the lifecycle tools only track state.

## Step-by-step

1. **Load scope.** `get_request`; read the task DAG and each task's
   least-privilege scope. Treat the scope as a hard boundary.
2. **Branch.** Create a feature branch (e.g. `req/REQ-2026-0428-fix-traversal`).
   Never work on or push a protected branch.
3. **Scaffold inside grant.** Implement tasks in DAG order. Touch only the
   paths/tools named in the task scope. Use `code_sample_search` + `docs_fetch`
   for references. If a task needs a capability outside the grant, **stop** and
   request a human grant change — do not broaden or work around it.
4. **Commit.** Make **signed**, **Conventional Commits 1.0.0** commits, English
   only, ASCII-clean (e.g. `fix(core-query): bound dependsOn traversal at depth 4`).
   Keep commits small and mapped to tasks. Never disable signing.
5. **Self-check (pre-review).** Run available local tests/lint within the
   sandbox. Confirm no secrets, no Turkish, no out-of-scope paths touched.
6. **Open draft PR (write).** Open a **draft** PR linked to the Request and its
   issue (and the Accepted RFC/ADR if design-class). Then call `advance_stage` to
   propose `implement -> review`. Do not request merge.

## Output format

```
Request: cogitave://request/REQ-2026-0428
Branch: req/REQ-2026-0428-fix-traversal
Commits (signed, Conventional):
  fix(core-query): bound dependsOn traversal at depth 4
  test(core-query): add depth-bound regression
Grant audit: PASS - only scoped paths/tools used; grant unchanged
Protected write/apply: NONE (held for review gate)
PR: draft #221 (links: issue, request, ADR-0004 if design-class)
Proposed: stage implement -> review (advance_stage, propose-only)
Next: /cogitave-flow:review REQ-2026-0428
```

## Examples

- Bound-traversal fix -> branch, two signed commits, draft PR, advance to review.
- Feature behind an Accepted RFC -> scaffold per DAG, draft PR linking the ADR.

## Edge cases

- **Task needs broader capability:** stop; request a human grant change. Never
  broaden the grant to "make a step easier" (AGENTS.md rule 5).
- **Out-of-scope path needed:** that is plan drift; return to `/cogitave-flow:plan`.
- **Design-class but RFC not Accepted:** refuse — implementation is blocked until
  Stage 4 reaches Accepted.
- **Any merge/apply/release/secret/protected-branch request:** refuse; that is the
  human gate at review.
- **Signing unavailable:** stop; unsigned commits are rejected by the ruleset.
