---
name: evaluate
description: >-
  Use this right after a Request exists in `stage: intake` and needs to be triaged
  / risk-assessed — "triage this request", "classify it", "is this RFC-worthy?",
  "is it safe?". Invoke BEFORE planning or coding. This automates Stage 2
  (evaluate) of the canonical lifecycle: it classifies type/area/impact, runs the
  security + dependency assessment by reusing the pr-triage, security-triage, and
  dependency-review scheduled agents, decides whether an RFC is needed, and
  proposes the advance to plan. Do NOT use it to do intake, build the task DAG, or
  write decisions.
allowed-tools:
  - mcp__cogitave-core__get_request
  - mcp__cogitave-core__query_graph
  - mcp__cogitave-core__get_related
  - mcp__cogitave-core__docs_search
  - mcp__cogitave-core__advance_stage
  - Read
  - Grep
  - Task
---

# Stage 2 - Evaluate (`/cogitave-flow:evaluate`)

Automates **Stage 2 (evaluate / triage / assess)** of the
[Request Lifecycle](../../../../../../cogitave/agents/lifecycle/LIFECYCLE.md#2-evaluate-triage--assess).
It classifies and risk-assesses a Request, then proposes its advance. The
classification it sets is what the
[Definition of Done](../../../../../../cogitave/agents/lifecycle/definition-of-done.md)
later uses to add conditional gate items, so it must be accurate.

## Purpose

Decide **what this change is** (`type`, `area`, `impact` flags), **whether it is
safe** (security + dependency clear), and **whether it needs an RFC**
(design-class), recording all of it on the Request node.

## When to use

- A Request is in `stage: intake` and needs triage sign-off.
- Re-triage when scope or impact changes.
- Do **not** use for intake, planning, or authoring decisions.

## Gate this skill enforces

**Evaluate gate:** **triage sign-off** (a `cogitave/<team>` owner accepts the
classification) **AND** **security clear** (no unresolved `security` finding).
Out-of-scope / duplicate -> `rejected` (terminal sub-state, with a recorded
reason). Only on a passing gate is `advance_stage` proposed.

## Reused scheduled agents (assessors)

This skill **orchestrates** the authoritative scheduled-agent specs; it does not
re-implement them. Spawn each as a subagent (`Task`) under its own grant:

- [`pr-triage`](../../../../../../cogitave/agents/scheduled/pr-triage.md) - type / area / size.
- [`security-triage`](../../../../../../cogitave/agents/scheduled/security-triage.md) - security impact + clear.
- [`dependency-review`](../../../../../../cogitave/agents/scheduled/dependency-review.md) - new/changed deps (license + provenance).

## MCP tools & resources used

- `mcp__cogitave-core__get_request` - load the Request (`cogitave://request/{id}`).
- `mcp__cogitave-core__query_graph` + `get_related` - find related/affected nodes
  to bound the assessment.
- `mcp__cogitave-core__docs_search` - prior decisions that imply RFC-needed.
- `mcp__cogitave-core__advance_stage` - **PROPOSE-ONLY write.** Records the
  classification + assessment + `rfcNeeded` decision and opens the advance
  (issue/PR comment + draft transition). It never merges, applies, or mutates
  protected state.

## Step-by-step

1. **Load.** `get_request` for the id; confirm it is in `stage: intake`.
2. **Classify.** Set `type` (feature/fix/docs/chore/refactor/infra/security/deps),
   `area`, and `impact` flags (`breaking` / `perf` / `security`). Run `pr-triage`
   for type/area/size signals.
3. **Assess security.** Spawn `security-triage`; capture its impact rating and
   clear/not-clear verdict. Any unresolved `security` finding blocks the gate.
4. **Assess dependencies.** If new/changed deps are implied, spawn
   `dependency-review`; capture license + provenance verdict (feeds DoD item D1).
5. **Decide RFC-needed.** Mark `rfcNeeded = true` if the change is design-class:
   new public surface, cross-cutting, `impact.breaking`, security-relevant, or a
   policy/contract change. Record the justification.
6. **Scope check.** If out-of-scope or a confirmed duplicate, set `rejected` with
   a reason via `advance_stage` and stop.
7. **Triage sign-off.** Present the classification to the accountable owner for
   sign-off (human-in-the-loop). Without sign-off, do not advance.
8. **Propose advance (write).** On sign-off + security clear, call `advance_stage`
   to `plan`, attaching the classification, the assessment records, and the
   `rfcNeeded` decision.

## Output format

```
Request: cogitave://request/REQ-2026-0428
Classification: type=fix area=core-query impact={perf:true}
security-triage: CLEAR (no new trust boundary)
dependency-review: n/a (no dep change)
rfcNeeded: false (not design-class)
Gate: PASS - triage sign-off (cogitave/platform) + security clear
Proposed: stage intake -> plan (advance_stage, propose-only)
Next: /cogitave-flow:plan REQ-2026-0428
```

## Examples

- Breaking public-API change -> `impact.breaking=true`, `rfcNeeded=true`; advance
  to `plan`, and `document` will be required downstream.
- Typo fix in a guide -> `type=docs`, `rfcNeeded=false`; advance straight toward
  `plan` then `implement` (document stage is skipped later).

## Edge cases

- **Security not clear:** gate fails; return the Request to the owner with the
  finding. Never advance over an unresolved `security` finding.
- **No owner sign-off:** hold in `evaluate`; do not self-approve.
- **Out-of-scope/duplicate:** `rejected` with reason (terminal), not silent drop.
- **Assessor disagreement:** record both; defer to Security for `impact.security`.
- **Wrong starting stage:** refuse if the Request is not in `intake`.
