---
name: intake
description: >-
  Use this the moment anyone (human or agent) wants to START a new unit of change
  in the Cogitave estate — a feature, fix, doc, infra change, dependency bump, or
  any "I want to request/propose X". Invoke BEFORE writing any code, opening any
  ad-hoc issue, or solutioning. This automates Stage 1 (intake) of the canonical
  request lifecycle: it captures the request as schema-valid structured data,
  opens a GitHub issue, stages a draft Core Request node (propose-only), and
  assigns an accountable triage owner. Do NOT use it to triage, plan, or
  implement — those are later stages.
allowed-tools:
  - mcp__cogitave-core__describe_schema
  - mcp__cogitave-core__docs_search
  - mcp__cogitave-core__get_related
  - mcp__cogitave-core__list_requests
  - mcp__cogitave-core__request_intake
  - Read
  - Grep
---

# Stage 1 - Intake (`/cogitave-flow:intake`)

Automates **Stage 1 (intake)** of the canonical
[Request Lifecycle](../../../../../../cogitave/agents/lifecycle/LIFECYCLE.md#1-intake).
A **Request** is a first-class Cogitave Core node (`cogitave://request/{id}`),
just like an Agent or a Doc; this skill creates one. It runs under the floor in
[`AGENTS.md`](../../../../../../AGENTS.md) (English only, least privilege, no
unapproved mutation, human-in-the-loop) and under the agent's own
[capability grant](../../../../../../cogitave/agents/identity/agent-identity-and-capabilities.md).

## Purpose

Turn an unstructured ask into a **schema-valid intake form**, a **GitHub issue**,
and a **draft Core Request node**, with an **accountable owner** assigned — the
clean entry point that every later stage builds on. No solutioning happens here.

## When to use

- Someone says "I want to request / propose / file / open" any change.
- A scheduled agent surfaces work that must enter the governed flow.
- Do **not** use for triage (`/cogitave-flow:evaluate`), planning, or coding.

## Gate this skill enforces

**Intake gate:** the intake form **validates** against
[`templates/intake-form.schema.json`](../../../../../../cogitave/agents/lifecycle/templates/intake-form.schema.json)
**AND** an `identity` (the acting principal) **AND** an `owner` (an accountable
`cogitave/<team>`) are set. **No owner -> no Request, no advance.** This skill
stops at a draft node in `stage: intake`; it never advances to evaluate.

## MCP tools & resources used

- `mcp__cogitave-core__describe_schema` - fetch the intake form shape to validate against.
- `mcp__cogitave-core__docs_search` + `mcp__cogitave-core__get_related` - dedupe
  against existing docs/decisions and related estate nodes.
- `mcp__cogitave-core__list_requests` - dedupe against existing/open Requests.
- `mcp__cogitave-core__request_intake` - **PROPOSE-ONLY write.** Opens the GitHub
  issue and stages the draft `cogitave://request/{id}` node. It does **not**
  mutate protected state, merge, apply, or release anything.
- Resource: `cogitave://request/{id}` (the staged draft node).

## Step-by-step

1. **Load the schema.** Call `describe_schema` for the intake form; treat its
   `required` fields as mandatory: problem statement, desired outcome,
   provisional `type`/`area`, requester `identity`.
2. **Elicit/normalize input.** Collect the fields from the user or surfacing
   agent. Write the problem as a *problem*, not a solution. English only,
   ASCII-clean. Reject Turkish or any non-English text.
3. **Dedupe.** Run `docs_search` + `get_related` on the problem statement and
   `list_requests` filtered by area; if a near-duplicate open Request exists,
   surface it and ask whether to link/comment instead of creating a new one.
4. **Validate.** Check the assembled form against the `describe_schema` output.
   On any missing/invalid required field, stop and ask — do not guess.
5. **Assign owner.** Resolve the accountable `cogitave/<team>` owner for the
   area (the triage owner). If none can be determined, stop: the gate fails
   without an owner.
6. **Propose intake (write).** Call `request_intake` with the validated form +
   `identity` + `owner`. This opens the issue and stages the draft node in
   `stage: intake`. Capture the returned `requestId` and issue URL.
7. **Report.** Echo the new `cogitave://request/{id}`, the issue link, the owner,
   and the dedupe result. State the next step is `/cogitave-flow:evaluate`.

## Output format

```
Request: cogitave://request/REQ-2026-0428  (stage: intake)
Issue:   <github issue url>
Type/Area (provisional): fix / core-query
Owner (triage, accountable): cogitave/platform
Dedupe: no open duplicate (checked 3 docs, 2 requests)
Gate: PASS - form valid, identity + owner set
Next: /cogitave-flow:evaluate REQ-2026-0428
```

## Examples

- "Open a request to fix the `dependsOn` traversal depth bug in Core query."
  -> validated fix-type form, issue, draft node, owner `cogitave/platform`.
- "I want to propose a new public MCP tool." -> intake form flags a likely
  design-class request in the notes; classification is still deferred to Stage 2.

## Edge cases

- **Missing owner:** gate fails; do not create the node. Ask for the owning team.
- **Duplicate found:** propose linking/commenting on the existing Request instead.
- **Underspecified ask:** request the missing required fields; never fabricate.
- **Non-English input:** refuse and ask for an English restatement.
- **Write tool unavailable / not in grant:** stop and report; do not fall back to
  raw `gh`/shell to mutate state — that would bypass propose-only governance.
- **Caller asks to also triage/plan now:** decline; hand off to the next skill.
