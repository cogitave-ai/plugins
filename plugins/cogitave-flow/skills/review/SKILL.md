---
name: review
description: >-
  Use this to PROVE a Request is done and decide whether it can merge — "review
  REQ-...", "run the Definition of Done", "is this ready to merge?". Invoke once a
  draft PR exists (stage: review). This automates Stage 6 (review): it runs the
  full Definition of Done, spawns the contribution-validator, doc-critic, and
  security/dependency reviewer agents in parallel for findings, and gates merge on
  DoD == 100% PLUS CODEOWNER approval. It NEVER merges itself — merge is the human
  CODEOWNER's consequential act. Do NOT use it to implement fixes or to advance
  before the gate is satisfied.
allowed-tools:
  - mcp__cogitave-core__get_request
  - mcp__cogitave-core__get_dod
  - mcp__cogitave-core__advance_stage
  - Read
  - Grep
  - Glob
  - Task
---

# Stage 6 - Review (`/cogitave-flow:review`)

Automates **Stage 6 (review)** of the
[Request Lifecycle](../../../../../../cogitave/agents/lifecycle/LIFECYCLE.md#6-review).
It runs the
[Definition of Done](../../../../../../cogitave/agents/lifecycle/definition-of-done.md)
as a machine-checkable gate and holds the **human-in-the-loop gate on
consequence**: only here may a human merge/apply.

## Purpose

Prove the change is **done** — DoD == 100% — gather critic/reviewer findings, and
record the CODEOWNER decision, **without merging**.

## When to use

- A Request is in `stage: review` with an open draft PR.
- Re-review after `review -> implement` changes were requested.
- Do **not** use to write fixes (that is `/cogitave-flow:implement`) or to skip
  the gate.

## Gate this skill enforces

**Review gate (the consequential, human gate):** **DoD == 100%** (every
applicable item `pass`, or validly `waived` with `{approver, reason}` — Core
items C1-C12 cannot be waived) **AND** **CODEOWNER approval**. DoD is the machine
gate; CODEOWNER is the separate human gate (separation of duties). Both required.
A failed gate returns the Request to `implement` with recorded reasons.

## Parallel reviewer agents (findings)

Spawn these as subagents (`Task`) in **parallel**; collect and de-duplicate
findings into the DoD evidence:

- **contribution-validator** - commits signed + Conventional, English only,
  docs-required satisfied, links complete, in-grant (C5/C6/C4/C11/C7/C8).
- **doc-critic** - docs match the change, no drift, accessibility on UI/docs
  surfaces (C4/A1).
- **security-triage** -
  [`../../../../../../cogitave/agents/scheduled/security-triage.md`](../../../../../../cogitave/agents/scheduled/security-triage.md)
  (S1/S2/C9).
- **dependency-review** -
  [`../../../../../../cogitave/agents/scheduled/dependency-review.md`](../../../../../../cogitave/agents/scheduled/dependency-review.md)
  (D1) when `type: deps` or deps changed.

## MCP tools & resources used

- `mcp__cogitave-core__get_request` - load the Request, PR, and classification.
- `mcp__cogitave-core__get_dod` - fetch the **scoped** DoD checklist (Core items +
  conditional items added by `type`/`impact`) and its machine result.
- `mcp__cogitave-core__advance_stage` - **PROPOSE-ONLY write.** Records the DoD
  result + critic findings + CODEOWNER decision and proposes `review -> done` (or
  `review -> implement`). It does **not** merge or apply; merge is the CODEOWNER's
  manual act outside this skill.
- Eval results come from the
  [eval harness](../../../../../../cogitave/agents/evals/eval-harness.md) (C3).

## Step-by-step

1. **Load.** `get_request` + `get_dod` for the id; read the scoped checklist.
2. **Fan out reviewers.** Spawn contribution-validator, doc-critic, and the
   security/dependency reviewers in parallel under their own grants. Keep only
   their conclusions (do not echo whole files back).
3. **Map findings to DoD items.** For each Core item C1-C12 and each conditional
   item, set `pass` / `fail` / `n/a` / `waived`. Attach the evidence source
   (PR review, CI job, eval run, security record, WORM trace).
4. **Compute the gate.** DoD is 100% only when **no `fail`**, every applicable
   item `pass` or validly `waived` (conditional only), with `{approver, reason}`
   recorded.
5. **Request CODEOWNER decision.** Surface the DoD result to the CODEOWNER for the
   affected areas; record approval/denial. This is the human gate; the skill does
   not self-approve.
6. **Propose transition (write).** If DoD == 100% **and** CODEOWNER approved,
   `advance_stage` proposes `review -> done`. Otherwise `advance_stage` returns
   `review -> implement` with the failing items and reasons. **Never merge here.**

## Output format

```
Request: cogitave://request/REQ-2026-0428
DoD (scoped): 12/12 applicable pass, 0 fail, 0 waived  -> result: done
  C3 Evals green: pass (cogitave://eval/run-9001)
  P1 Perf budget: pass (bench attached)
Critics: contribution-validator OK, doc-critic OK, security-triage CLEAR
CODEOWNER: approved (core-query)
Gate: PASS - DoD == 100% + CODEOWNER approval
Proposed: stage review -> done (advance_stage, propose-only)
Merge: held for human CODEOWNER (not performed by this skill)
Next: /cogitave-flow:doc-update REQ-2026-0428
```

## Examples

- All green + CODEOWNER approves -> propose `review -> done`; human merges.
- C3 evals fail -> gate fails; return to `implement` with the failing item.

## Edge cases

- **Core item failing/missing:** gate fails; Core items (C1-C12) cannot be waived.
- **Waiver without approver+reason:** invalid; treat as `fail`.
- **DoD 100% but no CODEOWNER approval:** hold; both gates are required (SoD).
- **Reviewer agent errors:** mark its item unresolved (not `pass`); do not guess.
- **Asked to merge/apply:** refuse; that is the human CODEOWNER's act.
