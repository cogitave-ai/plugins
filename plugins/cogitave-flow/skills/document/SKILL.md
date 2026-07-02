---
name: document
description: >-
  Use this for DESIGN-CLASS changes (new public surface, cross-cutting, breaking,
  security-relevant, or rfcNeeded == true) AFTER the plan is approved and BEFORE
  any code — "write the RFC", "author an ADR", "we need consensus on this design".
  This automates Stage 4 (document): it authors an RFC / ADR / design doc from the
  lifecycle templates with UID front matter, stores it under docs/decisions/, and
  drives the consensus / Final Comment Period gate to status: Accepted. Do NOT use
  it for non-design-class changes (those skip this stage) or to write code.
allowed-tools:
  - mcp__cogitave-core__get_request
  - mcp__cogitave-core__docs_search
  - mcp__cogitave-core__docs_fetch
  - mcp__cogitave-core__resolve_xref
  - mcp__cogitave-core__advance_stage
  - Read
  - Write
  - Edit
  - Grep
---

# Stage 4 - Document (`/cogitave-flow:document`)

Automates **Stage 4 (document, design-class only)** of the
[Request Lifecycle](../../../../../../cogitave/agents/lifecycle/LIFECYCLE.md#4-document-design-class-only).
Reach **written consensus before code**. Decisions are MADR-shaped with DocFX
UID front matter, per the
[documentation standard](../../../../../../cogitave/standards/docs/standards/documentation.md).

## Purpose

Author the **RFC / ADR / design doc** that records the decision, run it through a
**Final Comment Period (FCP)**, and reach **`status: Accepted` before any
implementation begins**.

## When to use

- A Request is in `stage: document` (design-class / `rfcNeeded == true`).
- A prior decision must be **superseded** (write a new ADR; never edit in place).
- Do **not** use for non-design-class changes — they advance `plan -> implement`
  and this stage is skipped.

## Gate this skill enforces

**Consensus / FCP gate:** a Final Comment Period **closes** and the RFC/ADR
reaches **`status: Accepted`** **before any code**. Until Accepted, the Request
stays in `document` (the lifecycle allows `document -> document` while the FCP is
open or changes are requested). Only then is the advance to `implement` proposed.

## MCP tools & resources used

- `mcp__cogitave-core__get_request` - load the Request + plan context.
- `mcp__cogitave-core__docs_search` + `docs_fetch` - prior art and any
  **superseded** decision to reference.
- `mcp__cogitave-core__resolve_xref` - resolve UID cross-references so links are
  valid in the UID graph.
- `mcp__cogitave-core__advance_stage` - **PROPOSE-ONLY write.** Opens the docs PR
  for the decision and records the FCP/consensus state. It does not merge the PR
  or apply anything; acceptance is a human/CODEOWNER act.

## Step-by-step

1. **Load + confirm class.** `get_request`; confirm `stage: document` and that the
   change is genuinely design-class. If not, stop and route back to `plan`.
2. **Gather prior art.** `docs_search`/`docs_fetch` for related and superseded
   decisions; `resolve_xref` to capture exact UIDs to link.
3. **Pick the template.** From
   [`templates/`](../../../../../../cogitave/agents/lifecycle/templates/) choose
   RFC vs ADR vs design-doc. ADRs are MADR-shaped.
4. **Author with UID front matter.** Write the doc with DocFX front matter:
   `uid: cogitave.<area>.<slug>`, `title`, `type: explanation` (or `reference`),
   `owner: cogitave/<team>`, `lastReviewed: 2026-06-28`, `status: draft`.
   English only, ASCII-clean. Capture context, options, decision, consequences.
5. **Store it.** Place the file under `docs/decisions/` in the target repo
   (e.g. `docs/decisions/0004-<slug>.md`). If superseding, link the old UID and
   set the old doc `status: superseded` in a *new* ADR — never edit the decision
   in place.
6. **Open FCP (write).** Call `advance_stage` to open the docs PR and start the
   **Final Comment Period**; notify CODEOWNERs and affected teams (RACI:
   Consulted). Loop `document -> document` while changes are requested.
7. **Reach Accepted.** When the FCP closes with consensus, set the decision
   `status: Accepted` and propose the advance to `implement` via `advance_stage`.

## Output format

```
Request: cogitave://request/REQ-2026-0431
Decision: docs/decisions/0004-public-query-cursor.md
  uid: cogitave.core.query-cursor  type: explanation  status: draft
Supersedes: cogitave.core.query-paging (ADR-0002) -> marked superseded
FCP: opened (docs PR #214), Consulted: CODEOWNER(core), cogitave/security
Gate: PENDING - awaiting FCP close + status: Accepted (no code yet)
Next (after Accepted): /cogitave-flow:implement REQ-2026-0431
```

## Examples

- New public MCP tool -> RFC with options + chosen design, FCP, Accepted, then
  implement.
- Replacing a deprecated decision -> new ADR that supersedes the old UID.

## Edge cases

- **Code requested before Accepted:** refuse; the gate forbids code until the FCP
  closes Accepted.
- **No consensus / changes requested:** stay in `document`; iterate the doc.
- **Editing an existing decision in place:** forbidden; author a superseding ADR.
- **Broken xref:** fix via `resolve_xref` before opening FCP; no dangling UIDs.
- **Non-design-class slipped in:** route back to `plan -> implement`, record skip.
