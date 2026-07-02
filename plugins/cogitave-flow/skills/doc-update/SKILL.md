---
name: doc-update
description: >-
  Use this as the COMPLETION step to close the loop after a Request has passed
  review (DoD == 100%, CODEOWNER approved, merge intended) — "finalize REQ-...",
  "update the changelog and docs", "record completion evidence". This automates
  Stage 7 (doc-update): idempotent, saga-like — it drafts the Keep a Changelog
  entry from the Conventional commits, syncs docs/ and RFC implementation notes,
  reindexes the UID graph, runs the doc-drift critic, and writes a
  completion-evidence token to Core (WORM), then proposes the final advance to
  done. It extends the changelog-docs-sync scheduled agent and stays propose-only.
  Do NOT use it before review passes.
allowed-tools:
  - mcp__cogitave-core__get_request
  - mcp__cogitave-core__docs_search
  - mcp__cogitave-core__resolve_xref
  - mcp__cogitave-core__advance_stage
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
  - Task
---

# Stage 7 - Doc-update / completion (`/cogitave-flow:doc-update`)

Automates **Stage 7 (doc-update, completion)** of the
[Request Lifecycle](../../../../../../cogitave/agents/lifecycle/LIFECYCLE.md#7-doc-update-completion).
It closes the loop after merge intent and writes the durable evidence that lets
an auditor answer "what shipped, and where is the proof?". It **extends** the
[`changelog-docs-sync`](../../../../../../cogitave/agents/scheduled/changelog-docs-sync.md)
scheduled agent.

## Purpose

Generate the changelog, **sync docs to the shipped change**, add RFC
implementation notes, **reindex the UID graph**, prove **no doc drift**, and write
the **completion-evidence token** — then advance `stage -> done`.

## When to use

- A Request is at completion (Stage 6 passed: DoD == 100% + CODEOWNER approval).
- Safe to re-run: this skill is **idempotent / saga-like** (see below).
- Do **not** use before review passes.

## Gate this skill enforces

**Completion gate:** **doc-drift critic clear** (docs match the shipped change)
**AND** **evidence recorded** (the completion token is written and queryable in
Core WORM). Only then is `advance_stage` proposed for the final `-> done`.

## Idempotent / saga semantics

Each step is a compensable saga step keyed by `requestId`:

- Re-running detects an existing `[Unreleased]` entry, doc sync, or evidence token
  and **updates in place** rather than duplicating (no double changelog lines, no
  duplicate tokens).
- If a step fails midway, completed steps are left in their consistent state and
  the skill resumes from the first incomplete step; it never advances to `done`
  until **all** steps and both gate conditions are satisfied.

## MCP tools & resources used

- `mcp__cogitave-core__get_request` - load the Request, its commits, and links.
- `mcp__cogitave-core__docs_search` - find the docs/RFC nodes to sync/annotate.
- `mcp__cogitave-core__resolve_xref` - validate UIDs before/after reindex.
- `mcp__cogitave-core__advance_stage` - **PROPOSE-ONLY write.** Records the
  changelog/doc-sync/evidence on the PR branch and proposes the final
  `review -> done` transition. It does **not** merge, release, or apply. On
  reindex, Core emits `notifications/resources/updated` for the changed UIDs (see
  [mcp-interface](../../../../../../cogitave/core/docs/mcp-interface.md)).

## Step-by-step

1. **Load.** `get_request`; gather the merged/intended Conventional commits and
   the Request links (issue, PR, Accepted RFC/ADR if design-class).
2. **Changelog (idempotent).** Spawn / extend `changelog-docs-sync` to draft a
   **Keep a Changelog 1.1.0** `[Unreleased]` entry from the commit `type`s
   (`feat`->Added, `fix`->Fixed, breaking->Changed + migration note). Update in
   place if an entry already exists.
3. **Sync docs.** Apply the doc changes the shipped behavior requires under
   `docs/`. For design-class Requests, add **RFC/ADR implementation notes** to
   the Accepted decision node (item R2).
4. **Reindex UID graph.** Trigger the UID reindex; confirm Core emits
   `notifications/resources/updated` for the changed UIDs; `resolve_xref` the
   touched UIDs to confirm no dangling references.
5. **Doc-drift critic.** Spawn the doc-drift critic (`Task`) to confirm docs
   match the shipped change. Any drift -> fix and re-run (saga resume); do not
   proceed while drift remains.
6. **Write completion evidence.** Write the **completion-evidence token** to Core
   (WORM, >= 1 year) bound to identity / `run_id` / spawn lineage. Idempotent on
   `requestId`.
7. **Propose done (write).** When the doc-drift critic is clear **and** the
   evidence token is written and queryable, call `advance_stage` for the final
   `review -> done`. This is the last transition; still propose-only.

## Output format

```
Request: cogitave://request/REQ-2026-0428
CHANGELOG: [Unreleased] Fixed - bound dependsOn traversal at depth 4 (idempotent)
Docs synced: docs/query.md; RFC impl notes: n/a (non-design-class)
UID reindex: 3 UIDs -> notifications/resources/updated emitted; xrefs clean
Doc-drift critic: CLEAR
Evidence token: cogitave://request/REQ-2026-0428#completion (WORM, written)
Gate: PASS - doc-drift clear + evidence recorded
Proposed: stage review -> done (advance_stage, propose-only; final)
```

## Examples

- Fix shipped -> `[Unreleased] Fixed` line, `docs/query.md` sync, reindex,
  evidence token, advance to `done`.
- Re-run after a transient failure -> existing changelog line + token detected and
  reused; resumes at the reindex step; no duplicates.

## Edge cases

- **Run before review passes:** refuse; completion requires DoD == 100% +
  CODEOWNER approval.
- **Doc drift detected:** hold in Stage 7; fix and resume the saga.
- **Reindex notification not observed:** treat the reindex as incomplete; retry
  before writing evidence.
- **Evidence write fails:** do not advance to `done`; evidence-recorded is a hard
  gate condition.
- **Duplicate changelog/token on re-run:** must not happen — update in place
  (idempotency on `requestId`).
- **Asked to merge/release/tag:** refuse; that is a human consequential act.
